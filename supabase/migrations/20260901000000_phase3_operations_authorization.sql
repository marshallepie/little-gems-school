-- Phase 3 operational authorization. Permission checks remain position-bound,
-- active-profile-bound and require the existing admin portal role.
insert into public.admin_permissions (code, name) values
  ('timetable.manage', 'Manage timetable entries'),
  ('attendance.review', 'Review and correct attendance'),
  ('assessments.review', 'Review assessments and results'),
  ('results.release', 'Release results to families'),
  ('communications.manage', 'Manage announcements'),
  ('calendar.manage', 'Manage school calendar events'),
  ('documents.manage', 'Manage private school documents')
on conflict (code) do update set name = excluded.name;

insert into public.admin_position_permissions (position_code, permission_code)
select p.position_code, p.permission_code
from (values
  ('proprietor_super_admin', 'timetable.manage'), ('proprietor_super_admin', 'attendance.review'),
  ('proprietor_super_admin', 'assessments.review'), ('proprietor_super_admin', 'results.release'),
  ('proprietor_super_admin', 'communications.manage'), ('proprietor_super_admin', 'calendar.manage'),
  ('proprietor_super_admin', 'documents.manage'),
  ('senior_administrator', 'timetable.manage'), ('senior_administrator', 'attendance.review'),
  ('senior_administrator', 'assessments.review'), ('senior_administrator', 'results.release'),
  ('senior_administrator', 'communications.manage'), ('senior_administrator', 'calendar.manage'),
  ('senior_administrator', 'documents.manage'),
  ('headmistress', 'timetable.manage'), ('headmistress', 'attendance.review'),
  ('headmistress', 'assessments.review'), ('headmistress', 'communications.manage'),
  ('headmistress', 'calendar.manage'), ('headmistress', 'documents.manage')
) as p(position_code, permission_code)
on conflict do nothing;

create function app_private.is_active_teacher_assignment(target_class_group_id uuid, target_subject_id uuid, target_term_id uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teachers t join public.teacher_assignments ta on ta.teacher_id = t.id
    join public.profiles p on p.id = t.profile_id and p.is_active
    where t.profile_id = (select auth.uid()) and t.employment_status = 'active'
      and ta.class_group_id = target_class_group_id and ta.subject_id = target_subject_id
      and (target_term_id is null or ta.term_id is null or ta.term_id = target_term_id)
  );
$$;

create function app_private.is_active_teacher_for_class(target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.teachers t join public.teacher_assignments ta on ta.teacher_id = t.id
    join public.profiles p on p.id = t.profile_id and p.is_active
    where t.profile_id = (select auth.uid()) and t.employment_status = 'active' and ta.class_group_id = target_class_group_id
  );
$$;

create function app_private.is_enrolled_on(target_student_id uuid, target_class_group_id uuid, on_date date)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.class_enrolments ce
    where ce.student_id = target_student_id and ce.class_group_id = target_class_group_id
      and ce.status = 'active' and ce.starts_on <= on_date and (ce.ends_on is null or ce.ends_on >= on_date));
$$;

create function app_private.is_active_student_self(target_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.students s join public.profiles p on p.id=s.profile_id and p.is_active where s.id=target_student_id and s.profile_id=(select auth.uid()));
$$;

create function app_private.is_active_guardian_of(target_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.guardians g join public.profiles p on p.id=g.profile_id and p.is_active join public.student_guardians sg on sg.guardian_id=g.id where g.profile_id=(select auth.uid()) and sg.student_id=target_student_id);
$$;

create function app_private.has_current_class_relationship(target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.is_active_teacher_for_class(target_class_group_id) or exists (
    select 1 from public.class_enrolments ce join public.academic_years ay on ay.id = (select cg.academic_year_id from public.class_groups cg where cg.id = ce.class_group_id)
    where ce.class_group_id = target_class_group_id and ay.is_current and ce.status = 'active'
      and ce.starts_on <= current_date and (ce.ends_on is null or ce.ends_on >= current_date)
      and (app_private.is_active_student_self(ce.student_id) or app_private.is_active_guardian_of(ce.student_id))
  );
$$;

create function app_private.matches_audience(target_kind text, target_role_code text, target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case target_kind
    when 'school' then exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.is_active)
    when 'role' then exists (select 1 from public.user_roles ur join public.roles r on r.id = ur.role_id join public.profiles p on p.id = ur.user_id and p.is_active where ur.user_id = (select auth.uid()) and r.code = target_role_code)
    when 'class' then app_private.has_current_class_relationship(target_class_group_id)
    else false end;
$$;

create function app_private.can_access_document(target_document_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.documents d where d.id = target_document_id and (
      app_private.has_admin_permission('documents.manage')
      or (d.created_by = (select auth.uid()))
      or (d.status = 'available' and exists (select 1 from public.document_targets dt where dt.document_id = d.id and app_private.matches_audience(dt.target_kind, dt.role_code, dt.class_group_id)))
    )
  );
$$;

revoke all on function app_private.is_active_teacher_assignment(uuid, uuid, uuid), app_private.is_active_teacher_for_class(uuid), app_private.is_enrolled_on(uuid, uuid, date), app_private.is_active_student_self(uuid), app_private.is_active_guardian_of(uuid), app_private.has_current_class_relationship(uuid), app_private.matches_audience(text, text, uuid), app_private.can_access_document(uuid) from public, anon;
grant execute on function app_private.is_active_teacher_assignment(uuid, uuid, uuid), app_private.is_active_teacher_for_class(uuid), app_private.is_enrolled_on(uuid, uuid, date), app_private.is_active_student_self(uuid), app_private.is_active_guardian_of(uuid), app_private.has_current_class_relationship(uuid), app_private.matches_audience(text, text, uuid), app_private.can_access_document(uuid) to authenticated;
