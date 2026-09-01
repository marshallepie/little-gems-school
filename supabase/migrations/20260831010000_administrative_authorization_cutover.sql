-- Authorization policy cutover. The preceding migration installs the operator-only
-- bootstrap capability; this migration fails closed unless its reviewed proprietor
-- mapping and every active admin mapping already exist. Therefore a normal
-- `supabase db push` cannot silently cut over an empty remote migration history.
select app_private.assert_administrative_authorization_ready();
drop policy profiles_own_or_admin_read on public.profiles;
drop policy profiles_admin_all on public.profiles;
drop policy user_roles_own_or_admin_read on public.user_roles;
drop policy user_roles_admin_all on public.user_roles;
drop policy students_relationship_read on public.students;
drop policy guardians_relationship_read on public.guardians;
drop policy student_guardians_relationship_read on public.student_guardians;
drop policy class_groups_relationship_read on public.class_groups;
drop policy enrolments_relationship_read on public.class_enrolments;
drop policy assignments_own_or_admin_read on public.teacher_assignments;
drop policy teachers_admin_all on public.teachers;
drop policy students_admin_all on public.students;
drop policy guardians_admin_all on public.guardians;
drop policy student_guardians_admin_all on public.student_guardians;
drop policy academic_years_admin_all on public.academic_years;
drop policy terms_admin_all on public.terms;
drop policy class_groups_admin_all on public.class_groups;
drop policy subjects_admin_all on public.subjects;
drop policy class_enrolments_admin_all on public.class_enrolments;
drop policy teacher_assignments_admin_all on public.teacher_assignments;

create policy user_roles_own_read on public.user_roles for select to authenticated using (user_id = (select auth.uid()));
create policy profiles_own_or_school_records_read on public.profiles for select to authenticated using (id = (select auth.uid()) or (select app_private.has_admin_permission('school_records.read')));
create policy students_relationship_or_admin_read on public.students for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or app_private.is_student_self(id) or app_private.is_guardian_of(id) or exists(select 1 from public.class_enrolments ce where ce.student_id = id and ce.status = 'active' and app_private.teaches_class(ce.class_group_id)));
create policy guardians_relationship_or_admin_read on public.guardians for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or profile_id = (select auth.uid()) or exists(select 1 from public.student_guardians sg where sg.guardian_id = id and app_private.is_student_self(sg.student_id)));
create policy student_guardians_relationship_or_admin_read on public.student_guardians for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or app_private.is_student_self(student_id) or app_private.is_guardian_of(student_id));
create policy class_groups_relationship_or_admin_read on public.class_groups for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or app_private.teaches_class(id) or exists(select 1 from public.class_enrolments ce where ce.class_group_id = id and (app_private.is_student_self(ce.student_id) or app_private.is_guardian_of(ce.student_id))));
create policy enrolments_relationship_or_admin_read on public.class_enrolments for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or app_private.is_student_self(student_id) or app_private.is_guardian_of(student_id) or app_private.teaches_class(class_group_id));
create policy assignments_own_or_admin_read on public.teacher_assignments for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or exists(select 1 from public.teachers t where t.id = teacher_id and t.profile_id = (select auth.uid())));
create policy teachers_permission_read on public.teachers for select to authenticated using ((select app_private.has_admin_permission('school_records.read')) or profile_id = (select auth.uid()));

create policy students_people_manage on public.students for all to authenticated using ((select app_private.has_admin_permission('people.manage'))) with check ((select app_private.has_admin_permission('people.manage')));
create policy guardians_people_manage on public.guardians for all to authenticated using ((select app_private.has_admin_permission('people.manage'))) with check ((select app_private.has_admin_permission('people.manage')));
create policy student_guardians_people_manage on public.student_guardians for all to authenticated using ((select app_private.has_admin_permission('people.manage'))) with check ((select app_private.has_admin_permission('people.manage')));
create policy teachers_people_manage on public.teachers for all to authenticated using ((select app_private.has_admin_permission('people.manage'))) with check ((select app_private.has_admin_permission('people.manage')));
create policy academic_years_structure_manage on public.academic_years for all to authenticated using ((select app_private.has_admin_permission('academic_structure.manage'))) with check ((select app_private.has_admin_permission('academic_structure.manage')));
create policy terms_structure_manage on public.terms for all to authenticated using ((select app_private.has_admin_permission('academic_structure.manage'))) with check ((select app_private.has_admin_permission('academic_structure.manage')));
create policy class_groups_structure_manage on public.class_groups for all to authenticated using ((select app_private.has_admin_permission('academic_structure.manage'))) with check ((select app_private.has_admin_permission('academic_structure.manage')));
create policy subjects_structure_manage on public.subjects for all to authenticated using ((select app_private.has_admin_permission('academic_structure.manage'))) with check ((select app_private.has_admin_permission('academic_structure.manage')));
create policy class_enrolments_manage on public.class_enrolments for all to authenticated using ((select app_private.has_admin_permission('enrolments.manage'))) with check ((select app_private.has_admin_permission('enrolments.manage')));
create policy teacher_assignments_manage on public.teacher_assignments for all to authenticated using ((select app_private.has_admin_permission('teacher_assignments.manage'))) with check ((select app_private.has_admin_permission('teacher_assignments.manage')));
