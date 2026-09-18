-- Account lifecycle and self-profile behavioural checks.
-- Run only after the administrative authorization cutover fixtures on a disposable local stack.
begin;

-- Auth create trigger supplies the initially unassigned profile that the proprietor RPC accepts.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'c1000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'lifecycle-user@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

-- Tier 2 cannot call lifecycle RPCs despite being an administrator.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000002', true);
do $$ begin
  begin
    perform public.provision_portal_account('c1000000-0000-0000-0000-000000000004', 'teacher', null);
    raise exception 'non-proprietor provisioned an account';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The exact proprietor position can provision a normalized role and records no secret in the audit event.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
select public.provision_portal_account('c1000000-0000-0000-0000-000000000004', 'teacher', null);
reset role;
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and default_role_code = 'teacher' and is_active) then raise exception 'provision did not activate default role'; end if;
  if not exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = 'c1000000-0000-0000-0000-000000000004' and r.code = 'teacher') then raise exception 'provision did not create normalized role'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_created' and metadata = '{}'::jsonb) then raise exception 'account-created audit event missing or contains metadata'; end if;
end $$;

-- A second active proprietor is never a deprovision target either: owner succession
-- is an operator-only workflow, so the same policy is safe for sole and multi-owner states.
update public.admin_position_assignments
  set position_code = 'proprietor_super_admin'
  where user_id = 'b1000000-0000-0000-0000-000000000002' and revoked_at is null;
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$ begin
  begin
    perform public.deprovision_portal_account('b1000000-0000-0000-0000-000000000002');
    raise exception 'active proprietor was deprovisioned';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
update public.admin_position_assignments
  set position_code = 'senior_administrator'
  where user_id = 'b1000000-0000-0000-0000-000000000002' and revoked_at is null;

-- An active user may update only the selected contact/completion fields. Avatar
-- uploads are server-mediated, so the retired external avatar URL is not writable.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000004', true);
update public.profiles set display_name = 'Lifecycle User', phone = '+2340000000', address = 'Test address', profile_completed_at = now() where id = 'c1000000-0000-0000-0000-000000000004';
do $$ begin
  begin
    update public.profiles set avatar_url = 'https://example.test/avatar.png' where id = 'c1000000-0000-0000-0000-000000000004';
    raise exception 'self profile changed the retired external avatar URL';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set default_role_code = 'admin' where id = 'c1000000-0000-0000-0000-000000000004';
    raise exception 'self profile changed role';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.profiles set is_active = true where id = 'c1000000-0000-0000-0000-000000000004';
    raise exception 'self profile changed active state';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Deprovision preserves the profile/records but removes its authorization path.
-- The external Auth-ban saga starts durably pending so a server failure cannot be
-- reported as complete; a proprietor can record failure and later complete retry.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
select public.deprovision_portal_account('c1000000-0000-0000-0000-000000000004');
reset role;
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and not is_active and auth_ban_state = 'pending') then raise exception 'deprovision did not leave durable pending Auth-ban state'; end if;
  if exists (select 1 from public.user_roles where user_id = 'c1000000-0000-0000-0000-000000000004') then raise exception 'deprovision retained role'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_deprovisioned') then raise exception 'deprovision audit event missing'; end if;
end $$;

-- Even with a still-valid JWT, a deprovisioned identity cannot update the
-- allowlisted contact fields directly through PostgREST/RLS.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000004', true);
do $$ begin
  update public.profiles
    set phone = '+234****9999'
    where id = 'c1000000-0000-0000-0000-000000000004';
  if found then
    raise exception 'deprovisioned account updated self contact data';
  end if;
end $$;
reset role;

-- Browser callers cannot forge saga state. The server-only capability requires the
-- service role and receives the original proprietor identity as an audited argument.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$ begin
  begin
    perform public.record_account_auth_ban_state_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'failed');
    raise exception 'authenticated caller forged an Auth-ban state event';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.record_account_auth_ban_state_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'failed');
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and not is_active and auth_ban_state = 'failed' and auth_ban_last_failed_at is not null) then raise exception 'Auth-ban failure was not durable'; end if;
  if exists (select 1 from public.user_roles where user_id = 'c1000000-0000-0000-0000-000000000004') then raise exception 'Auth-ban failure restored authorization'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_auth_ban_failed') then raise exception 'Auth-ban failure did not retain the proprietor actor'; end if;
end $$;
select public.record_account_auth_ban_state_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'succeeded');
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and auth_ban_state = 'succeeded' and auth_ban_completed_at is not null) then raise exception 'Auth-ban completion was not durable'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_auth_ban_completed') then raise exception 'Auth-ban completion did not retain the proprietor actor'; end if;
end $$;
reset role;

-- Re-provisioning is a trusted backend capability. Browser callers cannot invoke it,
-- and even a non-proprietor actor cannot use the service role to attribute a reset.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000002', true);
do $$ begin
  begin
    perform public.reprovision_portal_account_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000002', 'admin', 'headmistress');
    raise exception 'browser caller invoked re-provisioning capability';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- The reconciliation audit capability is likewise server-only, retains the
-- original active proprietor, and persists no metadata/secrets.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$ begin
  begin
    perform public.record_account_reprovision_reconciliation_needed_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001');
    raise exception 'browser caller recorded a re-provision reconciliation event';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.record_account_reprovision_reconciliation_needed_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001');
reset role;
do $$ begin
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_reprovision_reconciliation_needed' and metadata = '{}'::jsonb) then raise exception 're-provision reconciliation audit event missing or contains metadata'; end if;
end $$;

-- The original active proprietor can restore an Auth-ban-completed account with a
-- fresh role and position, but a trusted backend still validates a non-proprietor actor.
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  begin
    perform public.reprovision_portal_account_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000002', 'admin', 'headmistress');
    raise exception 'non-proprietor actor re-provisioned an account';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.reprovision_portal_account_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'admin', 'headmistress');
reset role;
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and is_active and default_role_code = 'admin' and auth_ban_state = 'not_required' and auth_ban_last_failed_at is null and auth_ban_completed_at is null) then raise exception 're-provision did not restore the active profile or clear Auth-ban status'; end if;
  if not exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id where ur.user_id = 'c1000000-0000-0000-0000-000000000004' and r.code = 'admin') then raise exception 're-provision did not restore the normalized selected role'; end if;
  if not exists (select 1 from public.admin_position_assignments where user_id = 'c1000000-0000-0000-0000-000000000004' and position_code = 'headmistress' and revoked_at is null) then raise exception 're-provision did not restore the selected administrator position'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'c1000000-0000-0000-0000-000000000004' and event_type = 'account_reprovisioned' and metadata = '{}'::jsonb) then raise exception 're-provision audit event missing or contains metadata'; end if;
end $$;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  begin
    perform public.reprovision_portal_account_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'teacher', null);
    raise exception 'active account was re-provisioned';
  exception when no_data_found then null;
  end;
  begin
    perform public.reprovision_portal_account_from_server('b1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'admin', 'senior_administrator');
    raise exception 'active proprietor account was re-provisioned';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- A fully deprovisioned account with a revoked proprietor assignment remains an
-- operator-only ownership-history record. The direct fixture is valid because
-- assignments are historical rows (revoked_at/revoked_by are both required);
-- lifecycle RPCs never grant or mutate proprietor assignments.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
select public.deprovision_portal_account('c1000000-0000-0000-0000-000000000004');
reset role;
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
select public.record_account_auth_ban_state_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'succeeded');
reset role;
insert into public.admin_position_assignments(user_id, position_code, assigned_by, revoked_at, revoked_by)
values ('c1000000-0000-0000-0000-000000000004', 'proprietor_super_admin', 'b1000000-0000-0000-0000-000000000001', now(), 'b1000000-0000-0000-0000-000000000001');
set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);
do $$ begin
  begin
    perform public.reprovision_portal_account_from_server('c1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'teacher', null);
    raise exception 'historical proprietor account was re-provisioned';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  if not exists (select 1 from public.profiles where id = 'c1000000-0000-0000-0000-000000000004' and not is_active and auth_ban_state = 'succeeded') then raise exception 'historical proprietor rejection reactivated the profile'; end if;
  if exists (select 1 from public.user_roles where user_id = 'c1000000-0000-0000-0000-000000000004') then raise exception 'historical proprietor rejection restored a normalized role'; end if;
  if exists (select 1 from public.admin_position_assignments where user_id = 'c1000000-0000-0000-0000-000000000004' and revoked_at is null) then raise exception 'historical proprietor fixture retained an active position'; end if;
end $$;

rollback;
\echo 'PASS: account lifecycle and self-profile behavioural tests'
