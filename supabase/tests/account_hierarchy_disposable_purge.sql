-- Self-contained transactional behavioural checks for the disposable purge hardening.
-- Run after the standard deterministic cutover fixture has applied all migrations.
\set ON_ERROR_STOP on
begin;

-- anon/authenticated inherit PUBLIC grants, so checking both proves neither direct
-- grants nor the default PUBLIC EXECUTE privilege expose this server-only saga.
do $$
declare
  function_signature text;
  browser_role name;
begin
  foreach function_signature in array array[
    'public.classify_disposable_test_account_from_server(uuid,uuid)',
    'public.begin_disposable_account_purge_from_server(uuid,uuid)',
    'public.record_disposable_account_purge_auth_failed_from_server(uuid,uuid)',
    'public.record_disposable_account_purge_auth_verification_failed_from_server(uuid,uuid)'
  ] loop
    foreach browser_role in array array['anon'::name, 'authenticated'::name] loop
      if has_function_privilege(browser_role, function_signature, 'execute') then
        raise exception 'browser role % retains EXECUTE on service-only function %', browser_role, function_signature;
      end if;
    end loop;
    if not has_function_privilege('service_role', function_signature, 'execute') then
      raise exception 'service_role lacks EXECUTE on required service-only function %', function_signature;
    end if;
  end loop;
end;
$$;

-- Every target gets a real Auth identity/profile via the production trigger.
insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email,
  '$2a$10$012345678901234567890u012345678901234567890123456789012', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()
from (values
  ('d1000000-0000-0000-0000-000000000001'::uuid, 'purge-retry@example.test'),
  ('d1000000-0000-0000-0000-000000000002'::uuid, 'purge-student@example.test'),
  ('d1000000-0000-0000-0000-000000000003'::uuid, 'purge-teacher@example.test'),
  ('d1000000-0000-0000-0000-000000000004'::uuid, 'purge-guardian@example.test'),
  ('d1000000-0000-0000-0000-000000000005'::uuid, 'purge-timetable@example.test'),
  ('d1000000-0000-0000-0000-000000000006'::uuid, 'purge-attendance@example.test'),
  ('d1000000-0000-0000-0000-000000000007'::uuid, 'purge-attendance-record@example.test'),
  ('d1000000-0000-0000-0000-000000000008'::uuid, 'purge-assignment@example.test'),
  ('d1000000-0000-0000-0000-000000000009'::uuid, 'purge-assessment@example.test'),
  ('d1000000-0000-0000-0000-000000000010'::uuid, 'purge-result@example.test'),
  ('d1000000-0000-0000-0000-000000000011'::uuid, 'purge-announcement@example.test'),
  ('d1000000-0000-0000-0000-000000000012'::uuid, 'purge-event@example.test'),
  ('d1000000-0000-0000-0000-000000000013'::uuid, 'purge-document@example.test'),
  ('d1000000-0000-0000-0000-000000000014'::uuid, 'purge-operational-audit@example.test'),
  ('d1000000-0000-0000-0000-000000000015'::uuid, 'purge-cms-page@example.test'),
  ('d1000000-0000-0000-0000-000000000016'::uuid, 'purge-cms-news@example.test'),
  ('d1000000-0000-0000-0000-000000000017'::uuid, 'purge-public-event@example.test'),
  ('d1000000-0000-0000-0000-000000000018'::uuid, 'purge-non-proprietor@example.test'),
  ('d1000000-0000-0000-0000-000000000019'::uuid, 'purge-fixture-teacher@example.test'),
  ('d1000000-0000-0000-0000-000000000020'::uuid, 'purge-authorization-history@example.test')
) as identities(id, email);

-- Valid relational fixtures make each Phase 3 insertion reach the purge gate.
insert into public.academic_years(id, name, starts_on, ends_on) values ('e1000000-0000-0000-0000-000000000001', 'Purge test year', '2026-01-01', '2026-12-31');
insert into public.terms(id, academic_year_id, name, starts_on, ends_on) values ('e1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', 'Purge term', '2026-01-01', '2026-06-30');
insert into public.class_groups(id, academic_year_id, name, level) values ('e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001', 'Purge class', '1');
insert into public.subjects(id, code, name) values ('e1000000-0000-0000-0000-000000000004', 'PURGE', 'Purge subject');
insert into public.teachers(id, profile_id, staff_number, first_name, last_name) values ('e1000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000019', 'PURGE-1', 'Fixture', 'Teacher');
insert into public.students(id, admission_number, first_name, last_name) values ('e1000000-0000-0000-0000-000000000006', 'PURGE-1', 'Fixture', 'Student');
insert into public.class_enrolments(student_id, class_group_id, starts_on) values ('e1000000-0000-0000-0000-000000000006', 'e1000000-0000-0000-0000-000000000003', '2026-01-01');
insert into public.teacher_assignments(id, teacher_id, class_group_id, subject_id, term_id) values ('e1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000002');
insert into public.attendance_sessions(id, class_group_id, attendance_date, teacher_assignment_id) values ('e1000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000003', '2026-02-02', 'e1000000-0000-0000-0000-000000000007');
insert into public.assessments(id, teacher_assignment_id, term_id, title, assessment_date, maximum_score) values ('e1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002', 'Fixture assessment', '2026-02-02', 100);

insert into public.students(profile_id, admission_number, first_name, last_name) values ('d1000000-0000-0000-0000-000000000002', 'PURGE-2', 'Blocked', 'Student');
insert into public.teachers(profile_id, staff_number, first_name, last_name) values ('d1000000-0000-0000-0000-000000000003', 'PURGE-2', 'Blocked', 'Teacher');
insert into public.guardians(profile_id, first_name, last_name, phone) values ('d1000000-0000-0000-0000-000000000004', 'Blocked', 'Guardian', '+100000');
insert into public.timetable_entries(term_id, class_group_id, subject_id, created_by, weekday, session_number, starts_at, ends_at) values ('e1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000005', 1, 1, '08:00', '09:00');
insert into public.attendance_sessions(class_group_id, attendance_date, session_number, teacher_assignment_id, created_by) values ('e1000000-0000-0000-0000-000000000003', '2026-02-03', 1, 'e1000000-0000-0000-0000-000000000007', 'd1000000-0000-0000-0000-000000000006');
insert into public.attendance_records(attendance_session_id, student_id, status, recorded_by) values ('e1000000-0000-0000-0000-000000000008', 'e1000000-0000-0000-0000-000000000006', 'present', 'd1000000-0000-0000-0000-000000000007');
insert into public.assignments(teacher_assignment_id, term_id, title, assigned_on, created_by) values ('e1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002', 'Blocked assignment', '2026-02-02', 'd1000000-0000-0000-0000-000000000008');
insert into public.assessments(teacher_assignment_id, term_id, title, assessment_date, maximum_score, created_by) values ('e1000000-0000-0000-0000-000000000007', 'e1000000-0000-0000-0000-000000000002', 'Blocked assessment', '2026-02-02', 100, 'd1000000-0000-0000-0000-000000000009');
insert into public.assessment_results(assessment_id, student_id, score, recorded_by) values ('e1000000-0000-0000-0000-000000000009', 'e1000000-0000-0000-0000-000000000006', 50, 'd1000000-0000-0000-0000-000000000010');
-- These provenance fixtures intentionally use distinct identities, but the
-- communications and CMS creator/lifecycle triggers require auth.uid() to be
-- that identity.  Bypass only those fixture-only triggers in this transactional
-- block; the rows retain real profile FKs for purge-preflight coverage.
set local session_replication_role = replica;
insert into public.announcements(title, body, created_by) values ('Blocked announcement', 'body', 'd1000000-0000-0000-0000-000000000011');
insert into public.events(title, starts_at, ends_at, created_by) values ('Blocked event', '2026-02-02 08:00+00', '2026-02-02 09:00+00', 'd1000000-0000-0000-0000-000000000012');
insert into public.cms_pages(slug, title, last_edited_by) values ('purge-blocked-page', 'Blocked page', 'd1000000-0000-0000-0000-000000000015');
insert into public.cms_news_posts(slug, title, status, published_at, published_by) values ('purge-blocked-news', 'Blocked news', 'published', '2026-02-02 08:00+00', 'd1000000-0000-0000-0000-000000000016');
insert into public.public_events(slug, title, starts_at, ends_at, created_by) values ('purge-blocked-public-event', 'Blocked public event', '2026-02-02 08:00+00', '2026-02-02 09:00+00', 'd1000000-0000-0000-0000-000000000017');
set local session_replication_role = origin;
insert into public.documents(title, file_name, mime_type, byte_size, created_by) values ('Blocked document', 'blocked.pdf', 'application/pdf', 10, 'd1000000-0000-0000-0000-000000000013');
insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type) values ('d1000000-0000-0000-0000-000000000014', 'event', 'e1000000-0000-0000-0000-000000000009', 'blocked');
insert into public.authorization_events(actor_user_id, subject_user_id, event_type) values ('b1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000020', 'account_created');

set local role service_role;
select set_config('request.jwt.claim.role', 'service_role', true);

-- The service capability rechecks the actor; Tier 2 cannot classify or purge.
do $$ begin
  begin
    perform public.classify_disposable_test_account_from_server('d1000000-0000-0000-0000-000000000018', 'b1000000-0000-0000-0000-000000000002');
    raise exception 'non-proprietor classified a disposable account';
  exception when insufficient_privilege then null;
  end;
end $$;

-- A failed external Auth delete leaves only purge-saga audit state. A second
-- preflight is a real retry, retains the proprietor actor, and remains pending.
select public.classify_disposable_test_account_from_server('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001');
select public.begin_disposable_account_purge_from_server('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001');
select public.record_disposable_account_purge_auth_failed_from_server('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001');
select public.begin_disposable_account_purge_from_server('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001');
do $$ begin
  if not exists (select 1 from public.profiles where id = 'd1000000-0000-0000-0000-000000000001' and not is_active and auth_ban_state = 'pending') then raise exception 'purge retry changed pending access state'; end if;
  if not exists (select 1 from public.authorization_events where actor_user_id = 'b1000000-0000-0000-0000-000000000001' and subject_user_id = 'd1000000-0000-0000-0000-000000000001' and event_type = 'disposable_account_purge_retry_started') then raise exception 'purge retry audit event missing'; end if;
end $$;

create function pg_temp.assert_purge_refused(target uuid, label text) returns void language plpgsql as $$
begin
  perform public.classify_disposable_test_account_from_server(target, 'b1000000-0000-0000-0000-000000000001');
  begin
    perform public.begin_disposable_account_purge_from_server(target, 'b1000000-0000-0000-0000-000000000001');
    raise exception '% did not block purge', label;
  exception when check_violation then null;
  end;
end;
$$;

-- Each fixed operational, communications, audit, person, and CMS provenance
-- family independently reaches and blocks the service-side purge preflight.
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000002', 'students');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000003', 'teachers');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000004', 'guardians');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000005', 'timetable_entries');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000006', 'attendance_sessions');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000007', 'attendance_records');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000008', 'assignments');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000009', 'assessments');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000010', 'assessment_results');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000011', 'announcements');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000012', 'events');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000013', 'documents');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000014', 'operational_events');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000015', 'cms_pages');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000016', 'cms_news_posts');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000017', 'public_events');
select pg_temp.assert_purge_refused('d1000000-0000-0000-0000-000000000020', 'authorization_events true history');

reset role;
rollback;
\echo 'PASS: disposable purge retry and provenance retention behavioural tests'
