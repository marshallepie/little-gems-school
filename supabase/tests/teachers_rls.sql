-- Behavioural RLS test for public.teachers.
-- Run after a clean local `supabase db reset`; see supabase/tests/README.md.
-- The transaction rolls back all identities and fixture data. Each assertion runs
-- as `authenticated` or `anon`, never as a table owner or service role.

begin;

-- Fixed test-only identities make the fixture deterministic and the rollback
-- keeps the reset database unchanged after this test.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'rls-admin@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'rls-teacher-a@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'rls-teacher-b@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'rls-parent@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('00000000-0000-0000-0000-000000000000', '10000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'rls-student@example.test', '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

insert into public.user_roles (user_id, role_id)
select v.user_id, r.id
from (values
  ('10000000-0000-0000-0000-000000000001'::uuid, 'admin'),
  ('10000000-0000-0000-0000-000000000002'::uuid, 'teacher'),
  ('10000000-0000-0000-0000-000000000003'::uuid, 'teacher'),
  ('10000000-0000-0000-0000-000000000004'::uuid, 'parent'),
  ('10000000-0000-0000-0000-000000000005'::uuid, 'student')
) as v(user_id, role_code)
join public.roles r on r.code = v.role_code;

insert into public.teachers (id, profile_id, staff_number, first_name, last_name)
values
  ('20000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000002', 'RLS-TEACHER-A', 'Teacher', 'A'),
  ('20000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000003', 'RLS-TEACHER-B', 'Teacher', 'B');

-- Admin: SELECT, INSERT, UPDATE, and DELETE all work through RLS.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.teachers where id in ('20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003')) <> 2 then
    raise exception 'admin cannot read all teacher fixtures';
  end if;
  insert into public.teachers (id, profile_id, staff_number, first_name, last_name)
  values ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'RLS-ADMIN-CRUD', 'Admin', 'Created');
  update public.teachers set last_name = 'Updated' where id = '20000000-0000-0000-0000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 1 or (select last_name from public.teachers where id = '20000000-0000-0000-0000-000000000001') <> 'Updated' then
    raise exception 'admin update failed';
  end if;
  delete from public.teachers where id = '20000000-0000-0000-0000-000000000001';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'admin delete failed'; end if;
end $$;
reset role;

-- Teacher A can read only the row tied to Teacher A's auth user.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000002', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.teachers where id = '20000000-0000-0000-0000-000000000002') <> 1 then
    raise exception 'Teacher A cannot read own record';
  end if;
  if (select count(*) from public.teachers where id = '20000000-0000-0000-0000-000000000003') <> 0 then
    raise exception 'Teacher A can read Teacher B';
  end if;
  update public.teachers set first_name = 'Mutated' where id = '20000000-0000-0000-0000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Teacher A updated a teacher'; end if;
  delete from public.teachers where id = '20000000-0000-0000-0000-000000000002';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Teacher A deleted a teacher'; end if;
  begin
    insert into public.teachers (profile_id, staff_number, first_name, last_name)
    values ('10000000-0000-0000-0000-000000000002', 'RLS-TEACHER-A-INSERT', 'No', 'Write');
    raise exception 'Teacher A inserted a teacher';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- Teacher B is also unable to mutate teacher records.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000003', true);
do $$
declare affected integer;
begin
  update public.teachers set first_name = 'Mutated' where id = '20000000-0000-0000-0000-000000000003';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Teacher B updated a teacher'; end if;
  delete from public.teachers where id = '20000000-0000-0000-0000-000000000003';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Teacher B deleted a teacher'; end if;
end $$;
reset role;

-- Parent and student have neither direct reads nor writes.
set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000004', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.teachers) <> 0 then raise exception 'parent can read teachers'; end if;
  update public.teachers set first_name = 'Mutated'; get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'parent updated teachers'; end if;
  delete from public.teachers; get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'parent deleted teachers'; end if;
  begin
    insert into public.teachers (profile_id, staff_number, first_name, last_name)
    values ('10000000-0000-0000-0000-000000000004', 'RLS-PARENT-INSERT', 'No', 'Write');
    raise exception 'parent inserted a teacher';
  exception when insufficient_privilege then null;
  end;
end $$;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000005', true);
do $$
declare affected integer;
begin
  if (select count(*) from public.teachers) <> 0 then raise exception 'student can read teachers'; end if;
  update public.teachers set first_name = 'Mutated'; get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'student updated teachers'; end if;
  delete from public.teachers; get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'student deleted teachers'; end if;
  begin
    insert into public.teachers (profile_id, staff_number, first_name, last_name)
    values ('10000000-0000-0000-0000-000000000005', 'RLS-STUDENT-INSERT', 'No', 'Write');
    raise exception 'student inserted a teacher';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

-- anon has no table grant, so the direct select must be rejected before any row is returned.
set local role anon;
do $$
begin
  begin
    perform 1 from public.teachers;
    raise exception 'anon can read teachers';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;

rollback;
\echo 'PASS: public.teachers behavioural RLS tests'
