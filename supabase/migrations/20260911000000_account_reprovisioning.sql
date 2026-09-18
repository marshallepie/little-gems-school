-- Proprietor-approved re-provisioning for accounts whose deprovision/Auth-ban
-- saga completed. Auth password reset and unban remain server-only; this trusted
-- capability restores only the database authorization state after that succeeds.

alter table public.authorization_events
  drop constraint authorization_events_event_type_check;
alter table public.authorization_events
  add constraint authorization_events_event_type_check check (event_type in (
    'position_assigned', 'position_revoked', 'role_assigned', 'role_revoked',
    'account_created', 'account_deprovisioned', 'account_auth_ban_failed', 'account_auth_ban_completed',
    'website_content_editor_granted', 'website_content_editor_revoked',
    'account_reprovisioned', 'account_reprovision_reconciliation_needed'
  ));

create function public.reprovision_portal_account_from_server(
  target_user_id uuid,
  actor_user_id uuid,
  target_role_code text,
  target_position_code text default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  selected_role_id uuid;
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'actor is not an active proprietor' using errcode = '42501';
  end if;
  if target_role_code not in ('admin', 'teacher', 'parent', 'student', 'secretary') then
    raise exception 'invalid portal role' using errcode = '22023';
  end if;
  if (target_role_code = 'admin') <> (target_position_code is not null) then
    raise exception 'administrator accounts require exactly one position' using errcode = '23514';
  end if;
  if target_position_code is not null and target_position_code not in ('senior_administrator', 'headmistress') then
    raise exception 'only delegable administrator positions may be re-provisioned' using errcode = '42501';
  end if;
  if not exists (select 1 from auth.users where id = target_user_id) then
    raise exception 'target must be an Auth identity' using errcode = '23503';
  end if;
  -- Never reactivate an owner account, including one with a historical proprietor
  -- assignment. Ownership succession remains an operator-only workflow.
  if exists (
    select 1 from public.admin_position_assignments
    where user_id = target_user_id and position_code = 'proprietor_super_admin'
  ) then
    raise exception 'a proprietor_super_admin account cannot be re-provisioned through account lifecycle' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.profiles
    where id = target_user_id and not is_active and auth_ban_state = 'succeeded'
  ) then
    raise exception 'target is not a fully deprovisioned account' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.user_roles where user_id = target_user_id) then
    raise exception 'target retains normalized roles and requires operator review' using errcode = '23514';
  end if;

  select id into selected_role_id from public.roles where code = target_role_code;
  if selected_role_id is null then
    raise exception 'selected portal role is unavailable' using errcode = '23503';
  end if;

  -- The server action has already atomically reset the password and removed the
  -- Auth ban. This is the final activation boundary; if it fails, the action
  -- compensates by re-banning the identity and authorization stays denied.
  update public.profiles
    set default_role_code = target_role_code,
        is_active = true,
        auth_ban_state = 'not_required',
        auth_ban_last_failed_at = null,
        auth_ban_completed_at = null
    where id = target_user_id;
  insert into public.user_roles(user_id, role_id) values (target_user_id, selected_role_id);
  if target_position_code is not null then
    insert into public.admin_position_assignments(user_id, position_code, assigned_by)
    values (target_user_id, target_position_code, actor_user_id);
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id, 'account_reprovisioned');
end;
$$;

-- An ambiguous activation response must be visible to an operator, but browsers
-- cannot forge this event and the event carries no password or other secret.
create function public.record_account_reprovision_reconciliation_needed_from_server(
  target_user_id uuid,
  actor_user_id uuid
)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.require_service_role();
  if not app_private.is_active_proprietor(actor_user_id) then
    raise exception 'actor is not an active proprietor' using errcode = '42501';
  end if;
  if not exists (select 1 from public.profiles where id = target_user_id) then
    raise exception 'target profile does not exist' using errcode = 'P0002';
  end if;
  insert into public.authorization_events(actor_user_id, subject_user_id, event_type)
  values (actor_user_id, target_user_id, 'account_reprovision_reconciliation_needed');
end;
$$;

revoke all on function public.reprovision_portal_account_from_server(uuid, uuid, text, text), public.record_account_reprovision_reconciliation_needed_from_server(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reprovision_portal_account_from_server(uuid, uuid, text, text), public.record_account_reprovision_reconciliation_needed_from_server(uuid, uuid) to service_role;
