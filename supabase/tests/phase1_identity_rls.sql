-- Phase 1 integrity and relationship RLS checks.
-- Run after `supabase db reset`, using the command in supabase/tests/README.md.
begin;

insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values
  ('00000000-0000-0000-0000-000000000000', 'a1000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'phase1-admin@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', 'a1000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'phase1-parent@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
insert into public.user_roles (user_id, role_id)
select v.user_id, r.id from (values
  ('a1000000-0000-0000-0000-000000000001'::uuid, 'admin'),
  ('a1000000-0000-0000-0000-000000000002'::uuid, 'parent')
) as v(user_id, role_code) join public.roles r on r.code = v.role_code;

-- Admin can create a person through the real RLS policy; no auth account is required.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
insert into public.students (id, admission_number, first_name, last_name)
values ('a2000000-0000-0000-0000-000000000001', 'RLS-PHASE1-001', 'Test', 'Pupil');
insert into public.guardians (id, first_name, last_name, phone)
values ('a3000000-0000-0000-0000-000000000001', 'Test', 'Guardian', '+2348000000001');
insert into public.student_guardians (student_id, guardian_id, relationship)
values ('a2000000-0000-0000-0000-000000000001', 'a3000000-0000-0000-0000-000000000001', 'Parent');
reset role;

-- A parent has no management write path, including an unrelated child link.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
do $$ begin
  begin
    insert into public.student_guardians (student_id, guardian_id, relationship)
    values ('60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'Unauthorised');
    raise exception 'parent inserted guardian relationship';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Database constraints reject two active classes for one student and terms outside their year.
set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
do $$
declare term_rejected boolean := false;
begin
  begin
    insert into public.class_enrolments (student_id, class_group_id, starts_on, status)
    values ('60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', '2026-09-01', 'active');
    raise exception 'second active enrolment was accepted';
  exception when unique_violation then null;
  end;
  begin
    insert into public.terms (academic_year_id, name, starts_on, ends_on)
    values ('10000000-0000-0000-0000-000000000001', 'Out of bounds', '2026-08-31', '2026-12-18');
  exception when raise_exception then
    term_rejected := true;
  end;
  if not term_rejected then raise exception 'out-of-year term was accepted'; end if;
end $$;
reset role;
rollback;
\echo 'PASS: Phase 1 integrity and relationship RLS tests'
