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

-- A user may update the selected basic fields, but column privileges prevent role or active-state escalation.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'c1000000-0000-0000-0000-000000000004', true);
update public.profiles set display_name = 'Lifecycle User', phone = '+2340000000', address = 'Test address', avatar_url = 'https://example.test/avatar.png', profile_completed_at = now() where id = 'c1000000-0000-0000-0000-000000000004';
do $$ begin
  begin
    update public.profiles set avatar_url = 'http://example.test/avatar.png' where id = 'c1000000-0000-0000-0000-000000000004';
    raise exception 'self profile bypassed HTTPS avatar policy';
  exception when check_violation then null;
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

rollback;
\echo 'PASS: account lifecycle and self-profile behavioural tests'
