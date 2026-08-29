-- Least-privilege access to staff records.
-- A teacher is linked to auth.users through teachers.profile_id -> profiles.id -> auth.users.id.

create policy teachers_admin_all on public.teachers
  for all to authenticated
  using ((select app_private.has_role('admin')))
  with check ((select app_private.has_role('admin')));

create policy teachers_self_read on public.teachers
  for select to authenticated
  using (profile_id = (select auth.uid()));
