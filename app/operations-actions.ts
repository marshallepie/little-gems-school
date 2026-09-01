"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminPermission, requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";
import { attendanceCorrectionSchema, attendanceSessionSchema, readAttendanceStatuses, timetableEntrySchema } from "@/lib/validations/operations";
import { formValues } from "@/lib/validations/school";

function fail(path: string, message: string): never {
  redirect(`${path}?error=${encodeURIComponent(message)}` as never);
}

function weekdayFor(date: string) {
  const day = new Date(`${date}T12:00:00Z`).getUTCDay();
  return day === 0 ? 7 : day;
}

export async function createTimetableEntry(formData: FormData) {
  const parsed = timetableEntrySchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/admin/operations/timetable", parsed.error.issues[0]?.message ?? "Invalid timetable entry");
  const supabase = await requireAdminPermission("timetable.manage");
  const { error } = await supabase.from("timetable_entries").insert({ ...parsed.data, teacher_assignment_id: parsed.data.teacher_assignment_id || null });
  if (error) fail("/admin/operations/timetable", error.message);
  revalidatePath("/admin/operations/timetable");
  redirect("/admin/operations/timetable?notice=Timetable+entry+saved" as never);
}

export async function correctAttendanceRecord(formData: FormData) {
  const parsed = attendanceCorrectionSchema.safeParse({
    ...formValues(formData), student_visible: formData.get("student_visible") === "on",
  });
  if (!parsed.success) fail("/admin/operations/attendance", parsed.error.issues[0]?.message ?? "Invalid attendance correction");
  const supabase = await requireAdminPermission("attendance.review");
  const { data: session, error: sessionError } = await supabase.from("attendance_sessions").select("id, status").eq("id", parsed.data.attendance_session_id).maybeSingle();
  if (sessionError || !session) fail("/admin/operations/attendance", "Attendance session is unavailable");
  const { error: recordError } = await supabase.from("attendance_records").update({ status: parsed.data.status }).eq("attendance_session_id", session.id).eq("student_id", parsed.data.student_id);
  if (recordError) fail("/admin/operations/attendance", recordError.message);
  const { error: updateError } = await supabase.from("attendance_sessions").update({ status: "corrected", student_visible: parsed.data.student_visible, submitted_at: new Date().toISOString() }).eq("id", session.id);
  if (updateError) fail("/admin/operations/attendance", updateError.message);
  revalidatePath("/admin/operations/attendance");
  redirect("/admin/operations/attendance?notice=Attendance+correction+saved" as never);
}

export async function saveTeacherAttendance(formData: FormData) {
  if (await requireRole() !== "teacher") redirect("/dashboard");
  const parsed = attendanceSessionSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/teacher/attendance", parsed.error.issues[0]?.message ?? "Invalid register details");
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) redirect("/login");

  const { data: teacher, error: teacherError } = await supabase.from("teachers").select("id, employment_status").eq("profile_id", userId).maybeSingle();
  if (teacherError || !teacher || teacher.employment_status !== "active") fail("/teacher/attendance", "Your active teacher record is unavailable");
  const { data: assignment, error: assignmentError } = await supabase
    .from("teacher_assignments")
    .select("id, class_group_id, term_id, class_groups(academic_year_id, academic_years(starts_on, ends_on, is_current)), terms(starts_on, ends_on)")
    .eq("id", parsed.data.teacher_assignment_id).eq("teacher_id", teacher.id).maybeSingle();
  if (assignmentError || !assignment) fail("/teacher/attendance", "Choose one of your active assignments");
  const classGroup = Array.isArray(assignment.class_groups) ? assignment.class_groups[0] : assignment.class_groups;
  const year = classGroup && (Array.isArray(classGroup.academic_years) ? classGroup.academic_years[0] : classGroup.academic_years);
  const term = Array.isArray(assignment.terms) ? assignment.terms[0] : assignment.terms;
  const dateIsValid = assignment.term_id
    ? Boolean(term && parsed.data.attendance_date >= term.starts_on && parsed.data.attendance_date <= term.ends_on)
    : Boolean(year?.is_current && parsed.data.attendance_date >= year.starts_on && parsed.data.attendance_date <= year.ends_on);
  if (!classGroup || !dateIsValid) fail("/teacher/attendance", "The attendance date must be within your assignment term or current academic year");

  if (parsed.data.timetable_entry_id) {
    const { data: timetable, error: timetableError } = await supabase.from("timetable_entries")
      .select("id, class_group_id, weekday, session_number, teacher_assignment_id")
      .eq("id", parsed.data.timetable_entry_id).maybeSingle();
    if (timetableError || !timetable || timetable.class_group_id !== assignment.class_group_id || timetable.weekday !== weekdayFor(parsed.data.attendance_date) || timetable.session_number !== parsed.data.session_number || (timetable.teacher_assignment_id && timetable.teacher_assignment_id !== assignment.id)) {
      fail("/teacher/attendance", "The selected timetable entry does not match your assignment, date, and session");
    }
  }

  const { data: roster, error: rosterError } = await supabase.from("class_enrolments").select("student_id")
    .eq("class_group_id", assignment.class_group_id).eq("status", "active")
    .lte("starts_on", parsed.data.attendance_date).or(`ends_on.is.null,ends_on.gte.${parsed.data.attendance_date}`);
  if (rosterError) fail("/teacher/attendance", "The eligible roster is unavailable");
  const records = readAttendanceStatuses(formData, (roster ?? []).map((row) => row.student_id));
  if (!records.success) fail("/teacher/attendance", records.error.issues[0]?.message ?? "Choose a status for every eligible student");

  const { data: existing, error: existingError } = await supabase.from("attendance_sessions").select("id, status")
    .eq("class_group_id", assignment.class_group_id).eq("attendance_date", parsed.data.attendance_date).eq("session_number", parsed.data.session_number).maybeSingle();
  if (existingError) fail("/teacher/attendance", existingError.message);
  let sessionId = existing?.id;
  if (existing && existing.status !== "draft") fail("/teacher/attendance", "Submitted registers cannot be edited by teachers");
  if (!sessionId) {
    const { data: created, error: createError } = await supabase.from("attendance_sessions").insert({
      class_group_id: assignment.class_group_id, teacher_assignment_id: assignment.id, attendance_date: parsed.data.attendance_date,
      session_number: parsed.data.session_number, timetable_entry_id: parsed.data.timetable_entry_id || null, status: "draft", student_visible: false,
    }).select("id").single();
    if (createError || !created) fail("/teacher/attendance", createError?.message ?? "Unable to create register");
    sessionId = created.id;
  }
  const { error: recordError } = await supabase.from("attendance_records").upsert(records.data.map((record) => ({ ...record, attendance_session_id: sessionId })), { onConflict: "attendance_session_id,student_id" });
  if (recordError) fail("/teacher/attendance", recordError.message);
  if (formData.get("intent") === "submit") {
    const { error: submitError } = await supabase.from("attendance_sessions").update({ status: "submitted", submitted_at: new Date().toISOString() }).eq("id", sessionId).eq("status", "draft");
    if (submitError) fail("/teacher/attendance", submitError.message);
  }
  revalidatePath("/teacher/attendance");
  redirect(`/teacher/attendance?notice=${formData.get("intent") === "submit" ? "Register+submitted" : "Draft+saved"}` as never);
}
