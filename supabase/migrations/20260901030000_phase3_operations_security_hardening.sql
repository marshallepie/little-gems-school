-- Append-only Phase 3 Batch 1 correction. No historical migration is rewritten.
-- Attendance registers are owned by a persisted, time-valid teacher assignment.

alter table public.attendance_sessions
  add column teacher_assignment_id uuid references public.teacher_assignments(id) on delete restrict;

update public.attendance_sessions s
set teacher_assignment_id = te.teacher_assignment_id
from public.timetable_entries te
where s.teacher_assignment_id is null
  and s.timetable_entry_id = te.id
  and te.teacher_assignment_id is not null;

do $$
begin
  if exists (select 1 from public.attendance_sessions where teacher_assignment_id is null) then
    raise exception 'attendance sessions require a persisted teacher assignment before Phase 3 hardening';
  end if;
end;
$$;
alter table public.attendance_sessions alter column teacher_assignment_id set not null;
create index attendance_sessions_teacher_assignment_idx on public.attendance_sessions(teacher_assignment_id);

-- Composite primary keys made the nullable audience columns implicitly NOT NULL.
alter table public.announcement_targets drop constraint announcement_targets_pkey;
alter table public.announcement_targets alter column role_code drop not null;
alter table public.announcement_targets alter column class_group_id drop not null;
alter table public.event_targets drop constraint event_targets_pkey;
alter table public.event_targets alter column role_code drop not null;
alter table public.event_targets alter column class_group_id drop not null;
alter table public.document_targets drop constraint document_targets_pkey;
alter table public.document_targets alter column role_code drop not null;
alter table public.document_targets alter column class_group_id drop not null;
create unique index announcement_targets_normalized_unique on public.announcement_targets(announcement_id, target_kind, role_code, class_group_id) nulls not distinct;
create unique index event_targets_normalized_unique on public.event_targets(event_id, target_kind, role_code, class_group_id) nulls not distinct;
create unique index document_targets_normalized_unique on public.document_targets(document_id, target_kind, role_code, class_group_id) nulls not distinct;

-- Every people-bound helper requires both the active portal role and matching active record.
create or replace function app_private.is_active_teacher_assignment(target_class_group_id uuid, target_subject_id uuid, target_term_id uuid default null)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.teachers t
    join public.teacher_assignments ta on ta.teacher_id = t.id
    join public.profiles p on p.id = t.profile_id and p.is_active
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'teacher'
    where t.profile_id = (select auth.uid()) and t.employment_status = 'active'
      and ta.class_group_id = target_class_group_id and ta.subject_id = target_subject_id
      and (target_term_id is null or ta.term_id is null or ta.term_id = target_term_id)
  );
$$;

create or replace function app_private.is_active_teacher_for_class(target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.teachers t
    join public.teacher_assignments ta on ta.teacher_id = t.id
    join public.profiles p on p.id = t.profile_id and p.is_active
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'teacher'
    join public.class_groups cg on cg.id = ta.class_group_id
    join public.academic_years ay on ay.id = cg.academic_year_id
    left join public.terms term on term.id = ta.term_id
    where t.profile_id = (select auth.uid()) and t.employment_status = 'active'
      and ta.class_group_id = target_class_group_id
      and ((ta.term_id is not null and current_date between term.starts_on and term.ends_on)
        or (ta.term_id is null and ay.is_current and current_date between ay.starts_on and ay.ends_on))
  );
$$;

create or replace function app_private.is_active_student_self(target_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.students s
    join public.profiles p on p.id = s.profile_id and p.is_active
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'student'
    where s.id = target_student_id and s.status = 'active' and s.profile_id = (select auth.uid())
  );
$$;

create or replace function app_private.is_active_guardian_of(target_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.guardians g
    join public.profiles p on p.id = g.profile_id and p.is_active
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'parent'
    join public.student_guardians sg on sg.guardian_id = g.id
    where g.profile_id = (select auth.uid()) and sg.student_id = target_student_id
  );
$$;

create function app_private.is_active_teacher_for_attendance_assignment(target_teacher_assignment_id uuid, target_class_group_id uuid, target_date date)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.teacher_assignments ta
    join public.teachers teacher on teacher.id = ta.teacher_id and teacher.employment_status = 'active'
    join public.profiles p on p.id = teacher.profile_id and p.is_active
    join public.user_roles ur on ur.user_id = p.id
    join public.roles r on r.id = ur.role_id and r.code = 'teacher'
    join public.class_groups cg on cg.id = ta.class_group_id
    join public.academic_years ay on ay.id = cg.academic_year_id
    left join public.terms term on term.id = ta.term_id
    where ta.id = target_teacher_assignment_id
      and teacher.profile_id = (select auth.uid())
      and ta.class_group_id = target_class_group_id
      and target_date between ay.starts_on and ay.ends_on
      and ((ta.term_id is not null and term.academic_year_id = ay.id and target_date between term.starts_on and term.ends_on)
        or (ta.term_id is null and ay.is_current))
  );
$$;

create function app_private.validate_attendance_session_hardening()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.teacher_assignments ta
    join public.class_groups cg on cg.id = ta.class_group_id
    join public.academic_years ay on ay.id = cg.academic_year_id
    left join public.terms term on term.id = ta.term_id
    where ta.id = new.teacher_assignment_id
      and ta.class_group_id = new.class_group_id
      and new.attendance_date between ay.starts_on and ay.ends_on
      and ((ta.term_id is not null and term.academic_year_id = ay.id and new.attendance_date between term.starts_on and term.ends_on)
        or (ta.term_id is null and ay.is_current))
  ) then
    raise exception 'attendance assignment must be for this class and valid on the attendance date' using errcode = '23514';
  end if;

  if new.timetable_entry_id is not null and not exists (
    select 1 from public.timetable_entries te
    join public.terms term on term.id = te.term_id
    where te.id = new.timetable_entry_id
      and te.class_group_id = new.class_group_id
      and te.session_number = new.session_number
      and extract(isodow from new.attendance_date) = te.weekday
      and new.attendance_date between term.starts_on and term.ends_on
      and (te.teacher_assignment_id is null or te.teacher_assignment_id = new.teacher_assignment_id)
  ) then
    raise exception 'attendance timetable must agree with class, date, session, and assignment' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger attendance_sessions_hardening_validate
before insert or update of class_group_id, attendance_date, session_number, timetable_entry_id, teacher_assignment_id
on public.attendance_sessions for each row execute procedure app_private.validate_attendance_session_hardening();

-- Correct singular audit entity names so assessment state transitions cannot fail.
create or replace function app_private.audit_phase3_transition()
returns trigger language plpgsql security definer set search_path = '' as $$
declare entity text;
begin
  if tg_op = 'UPDATE' and old.status is distinct from new.status then
    entity := case tg_table_name
      when 'attendance_sessions' then 'attendance_session'
      when 'assessments' then 'assessment'
      when 'documents' then 'document'
      else null
    end;
    if entity is not null then
      insert into public.operational_events(actor_user_id, entity_type, entity_id, event_type, metadata)
      values ((select auth.uid()), entity, new.id, 'status_changed', jsonb_build_object('from', old.status, 'to', new.status));
    end if;
  end if;
  return new;
end;
$$;

-- SECURITY DEFINER helpers read both sides of RLS relationships without recursive policies.
create function app_private.can_read_attendance_session(target_session_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.attendance_sessions s
    where s.id = target_session_id and (
      app_private.is_active_teacher_for_attendance_assignment(s.teacher_assignment_id, s.class_group_id, s.attendance_date)
      or (s.status in ('submitted', 'corrected') and exists (
        select 1 from public.attendance_records ar
        where ar.attendance_session_id = s.id
          and (app_private.is_active_guardian_of(ar.student_id)
            or (s.student_visible and app_private.is_active_student_self(ar.student_id)))
      ))
    )
  );
$$;

create function app_private.can_read_attendance_record(target_attendance_session_id uuid, target_student_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.attendance_sessions s
    where s.id = target_attendance_session_id and (
      app_private.is_active_teacher_for_attendance_assignment(s.teacher_assignment_id, s.class_group_id, s.attendance_date)
      or (s.status in ('submitted', 'corrected') and (
        app_private.is_active_guardian_of(target_student_id)
        or (s.student_visible and app_private.is_active_student_self(target_student_id))
      ))
    )
  );
$$;

create function app_private.can_read_announcement(target_announcement_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.announcements a where a.id = target_announcement_id and a.status = 'published' and exists (
    select 1 from public.announcement_targets t where t.announcement_id = a.id and app_private.matches_audience(t.target_kind, t.role_code, t.class_group_id)
  ));
$$;
create function app_private.can_read_announcement_target(target_announcement_id uuid, target_kind text, target_role_code text, target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.can_read_announcement(target_announcement_id)
    and app_private.matches_audience(target_kind, target_role_code, target_class_group_id);
$$;
create function app_private.can_read_event(target_event_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.events e where e.id = target_event_id and e.status = 'published' and not e.is_public and exists (
    select 1 from public.event_targets t where t.event_id = e.id and app_private.matches_audience(t.target_kind, t.role_code, t.class_group_id)
  ));
$$;
create function app_private.can_read_event_target(target_event_id uuid, target_kind text, target_role_code text, target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.can_read_event(target_event_id)
    and app_private.matches_audience(target_kind, target_role_code, target_class_group_id);
$$;
create function app_private.can_read_document_target(target_document_id uuid, target_kind text, target_role_code text, target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select app_private.can_access_document(target_document_id)
    and app_private.matches_audience(target_kind, target_role_code, target_class_group_id);
$$;
create function app_private.can_read_timetable_entry(target_class_group_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.class_enrolments ce
    join public.class_groups cg on cg.id = ce.class_group_id
    join public.academic_years ay on ay.id = cg.academic_year_id and ay.is_current
    where ce.class_group_id = target_class_group_id and ce.status = 'active'
      and ce.starts_on <= current_date and (ce.ends_on is null or ce.ends_on >= current_date)
      and (app_private.is_active_student_self(ce.student_id) or app_private.is_active_guardian_of(ce.student_id))
  );
$$;

revoke all on function app_private.is_active_teacher_for_attendance_assignment(uuid, uuid, date), app_private.validate_attendance_session_hardening(), app_private.can_read_attendance_session(uuid), app_private.can_read_attendance_record(uuid, uuid), app_private.can_read_announcement(uuid), app_private.can_read_announcement_target(uuid, text, text, uuid), app_private.can_read_event(uuid), app_private.can_read_event_target(uuid, text, text, uuid), app_private.can_read_document_target(uuid, text, text, uuid), app_private.can_read_timetable_entry(uuid) from public, anon, authenticated;
grant execute on function app_private.is_active_teacher_for_attendance_assignment(uuid, uuid, date), app_private.can_read_attendance_session(uuid), app_private.can_read_attendance_record(uuid, uuid), app_private.can_read_announcement(uuid), app_private.can_read_announcement_target(uuid, text, text, uuid), app_private.can_read_event(uuid), app_private.can_read_event_target(uuid, text, text, uuid), app_private.can_read_document_target(uuid, text, text, uuid), app_private.can_read_timetable_entry(uuid) to authenticated;

-- Replace every cross-table audience/session policy with the non-recursive helpers.
drop policy attendance_teacher_read on public.attendance_sessions;
drop policy attendance_teacher_insert_draft on public.attendance_sessions;
drop policy attendance_teacher_update_draft on public.attendance_sessions;
drop policy attendance_parent_student_read on public.attendance_sessions;
drop policy attendance_records_teacher_read on public.attendance_records;
drop policy attendance_records_teacher_draft_write on public.attendance_records;
drop policy attendance_records_teacher_draft_update on public.attendance_records;
drop policy attendance_records_family_read on public.attendance_records;
drop policy announcements_audience_read on public.announcements;
drop policy announcement_targets_audience_read on public.announcement_targets;
drop policy events_audience_read on public.events;
drop policy event_targets_audience_read on public.event_targets;
drop policy document_targets_available_read on public.document_targets;

create policy timetable_family_current_class_read on public.timetable_entries for select to authenticated using (app_private.can_read_timetable_entry(class_group_id));
create policy attendance_teacher_read on public.attendance_sessions for select to authenticated using (app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date));
create policy attendance_teacher_insert_draft on public.attendance_sessions for insert to authenticated with check (status = 'draft' and not student_visible and app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date));
create policy attendance_teacher_update_draft on public.attendance_sessions for update to authenticated using (status = 'draft' and app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date)) with check (status = 'draft' and not student_visible and app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date));
create policy attendance_family_read on public.attendance_sessions for select to authenticated using (app_private.can_read_attendance_session(id));
create policy attendance_records_teacher_read on public.attendance_records for select to authenticated using (app_private.can_read_attendance_record(attendance_session_id, student_id));
create policy attendance_records_teacher_draft_write on public.attendance_records for insert to authenticated with check (exists (select 1 from public.attendance_sessions s where s.id = attendance_session_id and s.status = 'draft' and app_private.is_active_teacher_for_attendance_assignment(s.teacher_assignment_id, s.class_group_id, s.attendance_date)));
create policy attendance_records_teacher_draft_update on public.attendance_records for update to authenticated using (exists (select 1 from public.attendance_sessions s where s.id = attendance_session_id and s.status = 'draft' and app_private.is_active_teacher_for_attendance_assignment(s.teacher_assignment_id, s.class_group_id, s.attendance_date))) with check (exists (select 1 from public.attendance_sessions s where s.id = attendance_session_id and s.status = 'draft' and app_private.is_active_teacher_for_attendance_assignment(s.teacher_assignment_id, s.class_group_id, s.attendance_date)));
create policy attendance_records_family_read on public.attendance_records for select to authenticated using (app_private.can_read_attendance_record(attendance_session_id, student_id));
create policy announcements_audience_read on public.announcements for select to authenticated using (app_private.can_read_announcement(id));
create policy announcement_targets_audience_read on public.announcement_targets for select to authenticated using (app_private.can_read_announcement_target(announcement_id, target_kind, role_code, class_group_id));
create policy events_audience_read on public.events for select to authenticated using (app_private.can_read_event(id));
create policy event_targets_audience_read on public.event_targets for select to authenticated using (app_private.can_read_event_target(event_id, target_kind, role_code, class_group_id));
create policy document_targets_available_read on public.document_targets for select to authenticated using (app_private.can_read_document_target(document_id, target_kind, role_code, class_group_id));
