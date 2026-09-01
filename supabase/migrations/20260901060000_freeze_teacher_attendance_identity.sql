-- Append-only correction: teachers may save or submit their own drafts, but may not
-- repurpose a persisted register by changing any part of its identity.
create function app_private.freeze_teacher_attendance_session_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not app_private.has_admin_permission('attendance.review')
    and (
      old.teacher_assignment_id is distinct from new.teacher_assignment_id
      or old.class_group_id is distinct from new.class_group_id
      or old.attendance_date is distinct from new.attendance_date
      or old.session_number is distinct from new.session_number
      or old.timetable_entry_id is distinct from new.timetable_entry_id
    ) then
    raise exception 'attendance register identity cannot be changed without attendance.review'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create trigger attendance_sessions_freeze_teacher_identity
before update on public.attendance_sessions
for each row execute procedure app_private.freeze_teacher_attendance_session_identity();

revoke all on function app_private.freeze_teacher_attendance_session_identity() from public, anon, authenticated;
