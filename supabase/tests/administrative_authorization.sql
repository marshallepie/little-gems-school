-- Behavioural authorization hierarchy/RLS cutover checks.
-- Run only against a reset local stack; fixtures are rolled back.
begin;

-- The cutover-gate fixture has already created and mapped the first three admins.
-- Add this deliberately unpositioned admin only after cutover, to verify default deny.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', 'b1000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'authz-unpositioned-admin@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
update public.profiles set default_role_code = 'admin' where id = 'b1000000-0000-0000-0000-000000000004';
insert into public.user_roles(user_id, role_id)
select 'b1000000-0000-0000-0000-000000000004'::uuid, id from public.roles where code = 'admin';

-- A legacy admin role alone has no post-cutover administrative access.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000004', true);
do $$ begin
  if app_private.has_admin_permission('school_records.read') then raise exception 'unpositioned admin retained read access'; end if;
  if (select count(*) from public.students) <> 0 then raise exception 'unpositioned admin can read students'; end if;
end $$;
reset role;

-- Tier 2 can manage people but not authorization; Tier 3 can manage academic structure but not people.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000002', true);
do $$ begin
  if not app_private.has_admin_permission('people.manage') then raise exception 'senior lacks people.manage'; end if;
  if app_private.has_admin_permission('authorization.manage') then raise exception 'senior received authorization.manage'; end if;
  insert into public.students(admission_number, first_name, last_name) values ('AUTHZ-SENIOR-001', 'Senior', 'Allowed');
  begin
    perform app_private.set_admin_position('b1000000-0000-0000-0000-000000000004', 'headmistress');
    raise exception 'senior delegated a position';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000003', true);
do $$ begin
  if not app_private.has_admin_permission('academic_structure.manage') then raise exception 'headmistress lacks academic structure permission'; end if;
  if app_private.has_admin_permission('people.manage') then raise exception 'headmistress received people.manage'; end if;
  begin
    insert into public.students(admission_number, first_name, last_name) values ('AUTHZ-HEAD-001', 'Head', 'Denied');
    raise exception 'headmistress created a student';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Even Tier 1 browser JWTs cannot call the former private helper or write audit
-- events. Position changes must use the server-only capability tested separately.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'b1000000-0000-0000-0000-000000000001', true);
do $$ begin
  if not app_private.has_admin_position('proprietor_super_admin') then raise exception 'proprietor lost active position'; end if;
  begin
    perform app_private.set_admin_position('b1000000-0000-0000-0000-000000000004', 'headmistress');
    raise exception 'authenticated Tier 1 called private position helper';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.authorization_events(event_type) values ('position_assigned');
    raise exception 'authenticated caller inserted audit event';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

rollback;
\echo 'PASS: administrative authorization hierarchy behavioural tests'
