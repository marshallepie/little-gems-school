-- Deterministic, fictional reference data only. No auth accounts, pupils, contacts, or credentials are seeded.
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
