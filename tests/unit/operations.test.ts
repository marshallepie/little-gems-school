import { describe, expect, it } from "vitest";
import { assessmentSchema, assignmentReviewSchema, assignmentSchema, attendanceSessionSchema, readAssessmentResults, readAttendanceStatuses, timetableEntrySchema } from "../../lib/validations/operations";

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

  it("rejects assignment date inversions and accepts a bounded draft payload", () => {
    const valid = { teacher_assignment_id: id, term_id: id, title: "Reading", instructions: "Read chapter 1", assigned_on: "2026-09-01", due_on: "2026-09-03" };
    expect(assignmentSchema.safeParse(valid).success).toBe(true);
    expect(assignmentSchema.safeParse({ ...valid, due_on: "2026-08-31" }).success).toBe(false);
  });

  it("allows only approved administrator assignment review targets", () => {
    expect(assignmentReviewSchema.safeParse({ assignment_id: id, target: "published" }).success).toBe(true);
    expect(assignmentReviewSchema.safeParse({ assignment_id: id, target: "closed" }).success).toBe(true);
    expect(assignmentReviewSchema.safeParse({ assignment_id: id, target: "draft" }).success).toBe(false);
  });

  it("requires a positive maximum assessment score", () => {
    const valid = { teacher_assignment_id: id, term_id: id, assignment_id: "", title: "Quiz", assessment_date: "2026-09-02", maximum_score: "10" };
    expect(assessmentSchema.safeParse(valid).success).toBe(true);
    expect(assessmentSchema.safeParse({ ...valid, maximum_score: "0" }).success).toBe(false);
  });

  it("shapes one valid result per server-selected roster pupil", () => {
    const form = new FormData(); form.set("assessment_id", id); form.set(`score_${id}`, "8.5"); form.set(`feedback_${id}`, "Good work");
    const parsed = readAssessmentResults(form, [id]);
    expect(parsed.success).toBe(true);
    if (parsed.success) expect(parsed.data).toEqual([{ assessment_id: id, student_id: id, score: 8.5, feedback: "Good work" }]);
  });
});
