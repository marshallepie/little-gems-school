import { z } from "zod";
import { uuid } from "./school";

const isoDate = z.string().date("Choose a valid date");
const isoTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, "Choose a valid time");

export const attendanceStatuses = ["present", "absent", "late", "excused"] as const;
export type AttendanceStatus = (typeof attendanceStatuses)[number];

export const timetableEntrySchema = z.object({
  term_id: uuid,
  class_group_id: uuid,
  subject_id: uuid,
  teacher_assignment_id: z.union([uuid, z.literal("")]),
  weekday: z.coerce.number().int().min(1).max(7),
  session_number: z.coerce.number().int().positive(),
  starts_at: isoTime,
  ends_at: isoTime,
}).refine(({ starts_at, ends_at }) => ends_at > starts_at, {
  path: ["ends_at"], message: "End time must be after start time",
});

export const attendanceSessionSchema = z.object({
  teacher_assignment_id: uuid,
  attendance_date: isoDate,
  session_number: z.coerce.number().int().positive(),
  timetable_entry_id: z.union([uuid, z.literal("")]),
});

export const attendanceRecordSchema = z.object({
  attendance_session_id: uuid,
  student_id: uuid,
  status: z.enum(attendanceStatuses),
});

export const attendanceCorrectionSchema = attendanceRecordSchema.extend({
  student_visible: z.boolean(),
});

export function readAttendanceStatuses(formData: FormData, studentIds: string[]) {
  const entries = studentIds.map((studentId) => ({
    attendance_session_id: String(formData.get("attendance_session_id") ?? ""),
    student_id: studentId,
    status: formData.get(`status_${studentId}`),
  }));
  return z.array(attendanceRecordSchema).min(1, "No eligible students were found").safeParse(entries);
}

const optionalUuid = z.union([uuid, z.literal("")]);
const optionalText = z.string().trim().max(2_000, "Feedback must be 2,000 characters or fewer");

export const assignmentSchema = z.object({
  teacher_assignment_id: uuid,
  term_id: uuid,
  title: z.string().trim().min(1, "Title is required").max(200, "Title must be 200 characters or fewer"),
  instructions: z.string().trim().max(10_000, "Instructions must be 10,000 characters or fewer"),
  assigned_on: isoDate,
  due_on: z.union([isoDate, z.literal("")]),
}).refine(({ assigned_on, due_on }) => !due_on || due_on >= assigned_on, {
  path: ["due_on"], message: "Due date cannot be before the assigned date",
});

export const assignmentIdSchema = z.object({ assignment_id: uuid });

export const assessmentSchema = z.object({
  teacher_assignment_id: uuid,
  term_id: uuid,
  assignment_id: optionalUuid,
  title: z.string().trim().min(1, "Title is required").max(200, "Title must be 200 characters or fewer"),
  assessment_date: isoDate,
  maximum_score: z.coerce.number().finite().positive("Maximum score must be greater than zero").max(999_999.99),
});

export const assessmentResultSchema = z.object({
  assessment_id: uuid,
  student_id: uuid,
  score: z.coerce.number().finite().min(0, "Score cannot be negative").max(999_999.99),
  feedback: optionalText,
});

export const releaseAssessmentSchema = z.object({ assessment_id: uuid });

export function readAssessmentResults(formData: FormData, studentIds: string[]) {
  const entries = studentIds.map((studentId) => ({
    assessment_id: String(formData.get("assessment_id") ?? ""),
    student_id: studentId,
    score: formData.get(`score_${studentId}`),
    feedback: formData.get(`feedback_${studentId}`) ?? "",
  }));
  return z.array(assessmentResultSchema).min(1, "No eligible students were found").safeParse(entries);
}
