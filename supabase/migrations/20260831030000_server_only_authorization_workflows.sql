-- Trusted backend capabilities for Auth-ban saga events and administrator-position
-- changes. Browser JWTs have no execute grant: server actions authenticate the
-- proprietor using the normal cookie-bound client, then call these narrowly scoped
-- service-role RPCs using the server-only Supabase client.

create function app_private.is_active_proprietor(actor uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'admin'
    join public.admin_position_assignments apa on apa.user_id = p.id
      and apa.position_code = 'proprietor_super_admin'
      and apa.revoked_at is null
    where p.id = actor and p.is_active and p.default_role_code = 'admin'
  );
$$;

create function app_private.require_service_role()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.role()) <> 'service_role' then
    raise exception 'trusted backend capability required' using errcode = '42501';
  end if;
end;
$$;

create function public.record_account_auth_ban_state_from_server(
  target_user_id uuid,
  actor_user_id uuid,
  outcome text
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'actor is not an active proprietor' using errcode = '42501';
  end if;
  if outcome not in ('failed', 'succeeded') then
    raise exception 'invalid Auth-ban outcome' using errcode = '22023';
  end if;

  update public.profiles
    set auth_ban_state = outcome,
        auth_ban_last_failed_at = case when outcome = 'failed' then now() else auth_ban_last_failed_at end,
        auth_ban_completed_at = case when outcome = 'succeeded' then now() else auth_ban_completed_at end
    where id = target_user_id and not is_active and auth_ban_state in ('pending', 'failed');
  if not found then
    raise exception 'target is not awaiting an Auth ban' using errcode = 'P0002';
  end if;

  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id,
    case when outcome = 'failed' then 'account_auth_ban_failed' else 'account_auth_ban_completed' end);
end;
$$;

create function public.set_admin_position_from_server(
  target_user_id uuid,
  actor_user_id uuid,
  target_position_code text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  current_position text;
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'actor is not an active proprietor' using errcode = '42501';
  end if;
  if target_user_id = actor_user_id then
    raise exception 'the proprietor cannot change their own position' using errcode = '42501';
  end if;
  if target_position_code is not null and target_position_code not in ('senior_administrator', 'headmistress') then
    raise exception 'only Tier 2 or Tier 3 positions may be assigned' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users where id = target_user_id) then
    raise exception 'target must be an Auth identity' using errcode = '23503';
  end if;
  if not exists (
    select 1 from public.profiles p
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'admin'
    where p.id = target_user_id and p.is_active and p.default_role_code = 'admin'
  ) then
    raise exception 'target must be an active administrator account' using errcode = '23514';
  end if;
  select position_code into current_position from public.admin_position_assignments
    where user_id = target_user_id and revoked_at is null for update;
  if current_position = 'proprietor_super_admin' then
    raise exception 'the proprietor position is bootstrap-only' using errcode = '42501';
  end if;
  if target_position_code is null and current_position is null then
    raise exception 'target has no active delegable position to revoke' using errcode = 'P0002';
  end if;
  if target_position_code is not null and current_position = target_position_code then
    raise exception 'target already has that position' using errcode = '23505';
  end if;

  update public.admin_position_assignments
    set revoked_at = now(), revoked_by = actor_user_id
    where user_id = target_user_id and revoked_at is null;
  if target_position_code is not null then
    insert into public.admin_position_assignments(user_id, position_code, assigned_by)
    values (target_user_id, target_position_code, actor_user_id);
  end if;
end;
$$;

-- Retire forgeable browser-facing saga endpoints entirely. Callers must use the
-- service-role capability above after the server has authenticated the proprietor.
drop function public.record_account_auth_ban_failure(uuid);
drop function public.record_account_auth_ban_completed(uuid);
revoke all on function app_private.set_admin_position(uuid, text) from public, anon, authenticated;
revoke all on function public.record_account_auth_ban_state_from_server(uuid, uuid, text), public.set_admin_position_from_server(uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.record_account_auth_ban_state_from_server(uuid, uuid, text), public.set_admin_position_from_server(uuid, uuid, text) to service_role;
revoke all on function app_private.is_active_proprietor(uuid), app_private.require_service_role() from public, anon, authenticated;
