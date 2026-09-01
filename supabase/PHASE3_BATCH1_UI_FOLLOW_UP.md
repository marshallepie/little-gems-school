# Phase 3 Batch 1: attendance UI follow-up

The attendance-register UI in the later Phase 3 batch must require a **persisted teacher assignment** when a teacher creates or edits a daily class register. The client must submit `teacher_assignment_id`; it may not infer authorization merely from class membership or an optional timetable row.

The register date must be within that assignment's term. An unscoped assignment is permitted only for the current academic year. If a timetable entry is linked, the UI must constrain the choices to the same class, weekday, session number, and (where set) teacher assignment. Administrators retain review/correction through `attendance.review`; teachers only access registers owned by their persisted valid assignment.
