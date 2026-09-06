-- Repair Phase 3 shared trigger dispatch without rewriting historical migrations.
-- Keep table-specific NEW references in a branch that only executes for that table.
create or replace function app_private.validate_phase3_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  a public.teacher_assignments%rowtype;
  d date;
  max_score numeric;
begin
  if tg_table_name = 'timetable_entries' then
    if not exists (
      select 1
      from public.terms t
      join public.class_groups c on c.academic_year_id = t.academic_year_id
      where t.id = new.term_id
        and c.id = new.class_group_id
    ) then
      raise exception 'timetable class must belong to term academic year'
        using errcode = '23514';
    end if;

    if new.teacher_assignment_id is not null and not exists (
      select 1
      from public.teacher_assignments ta
      where ta.id = new.teacher_assignment_id
        and ta.class_group_id = new.class_group_id
        and ta.subject_id = new.subject_id
        and (ta.term_id is null or ta.term_id = new.term_id)
    ) then
      raise exception 'timetable assignment mismatch'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'attendance_sessions' then
    if new.timetable_entry_id is not null and not exists (
      select 1
      from public.timetable_entries te
      where te.id = new.timetable_entry_id
        and te.class_group_id = new.class_group_id
        and extract(isodow from new.attendance_date) = te.weekday
        and te.session_number = new.session_number
    ) then
      raise exception 'attendance timetable mismatch'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'attendance_records' then
    select attendance_date
      into d
      from public.attendance_sessions
      where id = new.attendance_session_id;

    if not app_private.is_enrolled_on(
      new.student_id,
      (select class_group_id from public.attendance_sessions where id = new.attendance_session_id),
      d
    ) then
      raise exception 'attendance student is not eligible for session roster'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'assignments' then
    select *
      into a
      from public.teacher_assignments
      where id = new.teacher_assignment_id;

    if a.term_id is not null and a.term_id <> new.term_id then
      raise exception 'assignment term does not match teacher assignment'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.terms t
      join public.class_groups c on c.academic_year_id = t.academic_year_id
      where t.id = new.term_id
        and c.id = a.class_group_id
    ) then
      raise exception 'operational term/class mismatch'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.terms
      where id = new.term_id
        and new.assigned_on between starts_on and ends_on
    ) then
      raise exception 'assignment date outside term'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'assessments' then
    select *
      into a
      from public.teacher_assignments
      where id = new.teacher_assignment_id;

    if a.term_id is not null and a.term_id <> new.term_id then
      raise exception 'assignment term does not match teacher assignment'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.terms t
      join public.class_groups c on c.academic_year_id = t.academic_year_id
      where t.id = new.term_id
        and c.id = a.class_group_id
    ) then
      raise exception 'operational term/class mismatch'
        using errcode = '23514';
    end if;

    if not exists (
      select 1
      from public.terms
      where id = new.term_id
        and new.assessment_date between starts_on and ends_on
    ) then
      raise exception 'assessment date outside term'
        using errcode = '23514';
    end if;

    if new.assignment_id is not null and not exists (
      select 1
      from public.assignments x
      where x.id = new.assignment_id
        and x.teacher_assignment_id = new.teacher_assignment_id
        and x.term_id = new.term_id
    ) then
      raise exception 'assessment assignment mismatch'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'assessment_results' then
    select maximum_score
      into max_score
      from public.assessments
      where id = new.assessment_id;

    if new.score > max_score then
      raise exception 'score exceeds assessment maximum'
        using errcode = '23514';
    end if;

    if not app_private.is_enrolled_on(
      new.student_id,
      (
        select ta.class_group_id
        from public.assessments x
        join public.teacher_assignments ta on ta.id = x.teacher_assignment_id
        where x.id = new.assessment_id
      ),
      (select assessment_date from public.assessments where id = new.assessment_id)
    ) then
      raise exception 'result student not enrolled for assessment'
        using errcode = '23514';
    end if;

  elsif tg_table_name = 'documents' then
    if new.storage_path <> 'documents/' || new.id::text then
      raise exception 'document path must be deterministic'
        using errcode = '23514';
    end if;
  end if;

  return new;
end;
$$;

-- Trigger functions are not an application-callable API; this does not affect
-- execution through the existing table triggers.
revoke all on function app_private.validate_phase3_record()
  from public, anon, authenticated;
