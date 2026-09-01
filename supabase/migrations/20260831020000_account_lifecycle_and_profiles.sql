-- Proprietor-only account lifecycle and self-profile completion. Auth administration
-- remains in a server action; this migration never creates Auth identities or secrets.
alter table public.profiles
  add column address text,
  add column avatar_url text,
  add column profile_completed_at timestamptz,
  add column auth_ban_state text not null default 'not_required' check (auth_ban_state in ('not_required', 'pending', 'failed', 'succeeded')),
  add column auth_ban_last_failed_at timestamptz,
  add column auth_ban_completed_at timestamptz,
  add constraint profiles_avatar_url_https check (avatar_url is null or left(avatar_url, 8) = 'https://'),
  add constraint profiles_auth_ban_lifecycle check (
    (is_active and auth_ban_state = 'not_required' and auth_ban_last_failed_at is null and auth_ban_completed_at is null)
    or
    (not is_active and auth_ban_state in ('pending', 'failed', 'succeeded'))
  );

alter table public.authorization_events
  drop constraint authorization_events_event_type_check;
alter table public.authorization_events
  add constraint authorization_events_event_type_check check (event_type in (
    'position_assigned', 'position_revoked', 'role_assigned', 'role_revoked',
    'account_created', 'account_deprovisioned', 'account_auth_ban_failed', 'account_auth_ban_completed'
  ));

-- Account lifecycle requires the actual proprietor position, not merely a UI route
-- or a permission which might later be delegated to another position.
create function public.is_proprietor()
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.has_admin_position('proprietor_super_admin');
$$;

create function public.provision_portal_account(
  target_user_id uuid,
  target_role_code text,
  target_position_code text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
  selected_role_id uuid;
begin
  if not public.is_proprietor() then
    raise exception 'only the proprietor can provision accounts' using errcode = '42501';
  end if;
  if target_role_code not in ('admin', 'teacher', 'parent', 'student') then
    raise exception 'invalid portal role' using errcode = '22023';
  end if;
  if (target_role_code = 'admin') <> (target_position_code is not null) then
    raise exception 'administrator accounts require exactly one position' using errcode = '23514';
  end if;
  if target_position_code is not null and target_position_code not in ('senior_administrator', 'headmistress') then
    raise exception 'only delegable administrator positions may be provisioned' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users where id = target_user_id) then
    raise exception 'target must be an Auth identity' using errcode = '23503';
  end if;
  -- The Auth create trigger creates this unassigned profile. Refuse to repurpose
  -- an existing application account through an account-create request.
  if not exists (
    select 1 from public.profiles p
    where p.id = target_user_id and p.default_role_code is null and p.is_active
  ) or exists (select 1 from public.user_roles where user_id = target_user_id) then
    raise exception 'target is already provisioned or inactive' using errcode = '23505';
  end if;

  select id into selected_role_id from public.roles where code = target_role_code;
  update public.profiles set default_role_code = target_role_code where id = target_user_id;
  insert into public.user_roles(user_id, role_id) values (target_user_id, selected_role_id);
  if target_position_code is not null then
    insert into public.admin_position_assignments(user_id, position_code, assigned_by)
    values (target_user_id, target_position_code, actor);
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor, target_user_id, 'account_created');
end;
$$;

-- "Delete" is intentionally a logical deprovision: linked pupil/staff/guardian
-- records and audit history are retained, database authorization rejects the
-- profile, roles and positions are revoked, and the server then bans the Auth user.
create function public.deprovision_portal_account(target_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
begin
  if not public.is_proprietor() then
    raise exception 'only the proprietor can deprovision accounts' using errcode = '42501';
  end if;
  if target_user_id = actor then
    raise exception 'the proprietor cannot deprovision their own account' using errcode = '42501';
  end if;
  -- The proprietor mapping is bootstrap-only. Never deprovision an active owner,
  -- whether it is the sole owner or one of several active owners; operator-only
  -- succession must revoke/replace that mapping outside this lifecycle RPC first.
  if exists (
    select 1 from public.admin_position_assignments
    where user_id = target_user_id
      and position_code = 'proprietor_super_admin'
      and revoked_at is null
  ) then
    raise exception 'an active proprietor_super_admin cannot be deprovisioned through account lifecycle' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id and is_active) then
    raise exception 'target is not an active account' using errcode = 'P0002';
  end if;
  update public.admin_position_assignments
    set revoked_at = now(), revoked_by = actor
    where user_id = target_user_id and revoked_at is null;
  delete from public.user_roles where user_id = target_user_id;
  -- This transaction is the immediate authorization boundary. Auth banning is an
  -- external API call, so leave a durable incomplete state until the server has
  -- confirmed it and records completion through the restricted RPC below.
  update public.profiles
    set is_active = false,
        auth_ban_state = 'pending',
        auth_ban_last_failed_at = null,
        auth_ban_completed_at = null
    where id = target_user_id;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor, target_user_id, 'account_deprovisioned');
end;
$$;

-- These functions make the external Auth-ban saga observable and recoverable.
-- They intentionally cannot reactivate an account or alter its revoked roles.
create function public.record_account_auth_ban_failure(target_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
begin
  if not public.is_proprietor() then
    raise exception 'only the proprietor can record Auth-ban recovery state' using errcode = '42501';
  end if;
  update public.profiles
    set auth_ban_state = 'failed', auth_ban_last_failed_at = now()
    where id = target_user_id and not is_active and auth_ban_state in ('pending', 'failed');
  if not found then
    raise exception 'target is not awaiting an Auth ban' using errcode = 'P0002';
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor, target_user_id, 'account_auth_ban_failed');
end;
$$;

create function public.record_account_auth_ban_completed(target_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := (select auth.uid());
begin
  if not public.is_proprietor() then
    raise exception 'only the proprietor can complete an Auth ban' using errcode = '42501';
  end if;
  update public.profiles
    set auth_ban_state = 'succeeded', auth_ban_completed_at = now()
    where id = target_user_id and not is_active and auth_ban_state in ('pending', 'failed');
  if not found then
    raise exception 'target is not awaiting an Auth ban' using errcode = 'P0002';
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor, target_user_id, 'account_auth_ban_completed');
end;
$$;

-- Account contacts stay private to their owner. Column grants are the database
-- enforcement that limits self-editing to precisely the completion fields.
drop policy profiles_own_or_school_records_read on public.profiles;
drop policy profiles_own_update on public.profiles;
create policy profiles_self_read on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profiles_self_contact_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));
revoke update on public.profiles from authenticated;
grant update (display_name, phone, address, avatar_url, profile_completed_at) on public.profiles to authenticated;

revoke all on function public.is_proprietor(), public.provision_portal_account(uuid, text, text), public.deprovision_portal_account(uuid), public.record_account_auth_ban_failure(uuid), public.record_account_auth_ban_completed(uuid) from public, anon;
grant execute on function public.is_proprietor(), public.provision_portal_account(uuid, text, text), public.deprovision_portal_account(uuid), public.record_account_auth_ban_failure(uuid), public.record_account_auth_ban_completed(uuid) to authenticated;
