-- Deterministic fictional Phase 1 fixtures. Portal accounts are intentionally not
-- seeded: local auth identities are created by behavioural RLS tests instead.
insert into public.roles (code, name) values
  ('admin', 'Administrator'), ('teacher', 'Teacher'), ('parent', 'Parent / Guardian'), ('student', 'Student')
on conflict (code) do update set name = excluded.name;

insert into public.academic_years (id, name, starts_on, ends_on, is_current) values
  ('10000000-0000-0000-0000-000000000001', '2026/2027', '2026-09-01', '2027-07-31', true)
on conflict (id) do nothing;
insert into public.terms (id, academic_year_id, name, starts_on, ends_on) values
  ('20000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Term 1', '2026-09-01', '2026-12-18')
on conflict (id) do nothing;
insert into public.subjects (id, code, name) values
  ('30000000-0000-0000-0000-000000000001', 'ENG', 'English'),
  ('30000000-0000-0000-0000-000000000002', 'MAT', 'Mathematics')
on conflict (id) do nothing;
insert into public.class_groups (id, academic_year_id, name, level) values
  ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Foundation A', 'Foundation'),
  ('40000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Foundation B', 'Foundation')
on conflict (id) do nothing;

insert into public.teachers (id, staff_number, first_name, last_name) values
  ('50000000-0000-0000-0000-000000000001', 'T-100', 'Amina', 'Okafor')
on conflict (id) do nothing;
insert into public.students (id, admission_number, first_name, last_name, date_of_birth) values
  ('60000000-0000-0000-0000-000000000001', 'LG-2026-001', 'Ada', 'Okafor', '2021-05-12')
on conflict (id) do nothing;
insert into public.guardians (id, first_name, last_name, phone, email) values
  ('70000000-0000-0000-0000-000000000001', 'Chinwe', 'Okafor', '+2348000000000', 'chinwe.okafor@example.test')
on conflict (id) do nothing;
insert into public.student_guardians (student_id, guardian_id, relationship, is_primary_contact) values
  ('60000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001', 'Mother', true)
on conflict (student_id, guardian_id) do nothing;
insert into public.class_enrolments (id, student_id, class_group_id, starts_on, status) values
  ('80000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '2026-09-01', 'active')
on conflict (id) do nothing;
insert into public.teacher_assignments (id, teacher_id, class_group_id, subject_id, term_id) values
  ('90000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;
