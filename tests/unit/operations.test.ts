import { describe, expect, it } from "vitest";
import { attendanceSessionSchema, readAttendanceStatuses, timetableEntrySchema } from "../../lib/validations/operations";

const id = "11111111-1111-4111-8111-111111111111";

describe("Phase 3 Batch 2 operation validation", () => {
  it("rejects timetable entries with an invalid weekday or reversed time", () => {
    expect(timetableEntrySchema.safeParse({ term_id: id, class_group_id: id, subject_id: id, teacher_assignment_id: "", weekday: 0, session_number: 1, starts_at: "09:00", ends_at: "10:00" }).success).toBe(false);
    expect(timetableEntrySchema.safeParse({ term_id: id, class_group_id: id, subject_id: id, teacher_assignment_id: id, weekday: 1, session_number: 1, starts_at: "10:00", ends_at: "09:00" }).success).toBe(false);
  });
  it("requires a persisted assignment, date and positive session for a register", () => {
    expect(attendanceSessionSchema.safeParse({ teacher_assignment_id: id, attendance_date: "2026-09-01", session_number: 1, timetable_entry_id: "" }).success).toBe(true);
    expect(attendanceSessionSchema.safeParse({ teacher_assignment_id: "", attendance_date: "not-a-date", session_number: 0, timetable_entry_id: "" }).success).toBe(false);
  });
  it("requires a valid attendance status for every roster student", () => {
    const form = new FormData(); form.set("attendance_session_id", id); form.set(`status_${id}`, "present");
    expect(readAttendanceStatuses(form, [id]).success).toBe(true);
    form.set(`status_${id}`, "unknown");
    expect(readAttendanceStatuses(form, [id]).success).toBe(false);
  });
});
