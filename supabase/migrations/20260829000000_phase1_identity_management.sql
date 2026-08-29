-- Phase 1: complete admin management and integrity for identity/school structure.
-- Portal accounts are optional for people records; an administrator can create a
-- staff/student/guardian record before its auth invitation is provisioned.
alter table public.teachers alter column profile_id drop not null;

-- A term and its class/teacher assignment must belong to the same academic year.
create function app_private.ensure_term_within_academic_year()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  year_starts date;
  year_ends date;
begin
  select starts_on, ends_on into year_starts, year_ends
  from public.academic_years
  where id = new.academic_year_id;

  if new.starts_on < year_starts or new.ends_on > year_ends then
    raise exception 'term dates must fall within its academic year';
  end if;
  return new;
end;
$$;

create trigger terms_dates_within_academic_year
before insert or update of academic_year_id, starts_on, ends_on on public.terms
for each row execute procedure app_private.ensure_term_within_academic_year();

create function app_private.ensure_assignment_term_matches_class_year()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.term_id is not null and not exists (
    select 1
    from public.terms term
    join public.class_groups class_group on class_group.id = new.class_group_id
    where term.id = new.term_id
      and term.academic_year_id = class_group.academic_year_id
  ) then
    raise exception 'teacher assignment term must belong to the class academic year';
  end if;
  return new;
end;
$$;

create trigger teacher_assignments_term_matches_class_year
before insert or update of class_group_id, term_id on public.teacher_assignments
for each row execute procedure app_private.ensure_assignment_term_matches_class_year();

-- A pupil can have one active class at a time; historical enrolments remain.
create unique index class_enrolments_one_active_class_per_student
  on public.class_enrolments(student_id)
  where status = 'active';

-- Admins manage Phase 1 records. All other policies remain relationship-based
-- and default-deny for writes. Roles themselves are fixed migration data.
create policy profiles_admin_all on public.profiles
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy user_roles_admin_all on public.user_roles
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy students_admin_all on public.students
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy guardians_admin_all on public.guardians
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy student_guardians_admin_all on public.student_guardians
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy academic_years_admin_all on public.academic_years
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy terms_admin_all on public.terms
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy class_groups_admin_all on public.class_groups
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy subjects_admin_all on public.subjects
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy class_enrolments_admin_all on public.class_enrolments
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy teacher_assignments_admin_all on public.teacher_assignments
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

-- `teachers_admin_all` was introduced in the preceding migration.
