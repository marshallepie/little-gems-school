-- Allow an owning teacher to make the one-way draft-to-submitted transition.
-- The USING clause continues to authorize only the old, persisted draft row;
-- the CHECK clause keeps both draft saves and submissions non-student-visible.
drop policy attendance_teacher_update_draft on public.attendance_sessions;

create policy attendance_teacher_update_draft on public.attendance_sessions
for update to authenticated
using (
  status = 'draft'
  and app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date)
)
with check (
  status in ('draft', 'submitted')
  and not student_visible
  and (status = 'draft' or submitted_at is not null)
  and app_private.is_active_teacher_for_attendance_assignment(teacher_assignment_id, class_group_id, attendance_date)
);
