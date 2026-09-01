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
