"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminPermission, requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";
import { assessmentSchema, assignmentIdSchema, assignmentSchema, attendanceCorrectionSchema, attendanceSessionSchema, readAssessmentResults, readAttendanceStatuses, releaseAssessmentSchema, timetableEntrySchema } from "@/lib/validations/operations";
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

async function ownTeacherAssignment(supabase: Awaited<ReturnType<typeof createClient>>, userId: string, assignmentId: string) {
  const { data: teacher, error: teacherError } = await supabase.from("teachers").select("id, employment_status").eq("profile_id", userId).maybeSingle();
  if (teacherError || !teacher || teacher.employment_status !== "active") return null;
  const { data, error } = await supabase.from("teacher_assignments").select("id, class_group_id, term_id").eq("id", assignmentId).eq("teacher_id", teacher.id).maybeSingle();
  return error ? null : data;
}

async function teacherClient() {
  if (await requireRole() !== "teacher") redirect("/dashboard");
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  return { supabase, userId: claims.claims.sub };
}

export async function saveTeacherAssignment(formData: FormData) {
  const parsed = assignmentSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/teacher/assignments", parsed.error.issues[0]?.message ?? "Invalid assignment");
  const { supabase, userId } = await teacherClient();
  const teaching = await ownTeacherAssignment(supabase, userId, parsed.data.teacher_assignment_id);
  if (!teaching || (teaching.term_id && teaching.term_id !== parsed.data.term_id)) fail("/teacher/assignments", "Choose one of your valid teaching assignments");
  const assignmentId = String(formData.get("assignment_id") ?? "");
  const payload = { ...parsed.data, due_on: parsed.data.due_on || null, created_by: userId, status: "draft" as const, published_at: null };
  if (assignmentId) {
    const id = assignmentIdSchema.safeParse({ assignment_id: assignmentId });
    if (!id.success) fail("/teacher/assignments", "Invalid assignment");
    const { data: existing, error: existingError } = await supabase.from("assignments").select("id, status").eq("id", id.data.assignment_id).maybeSingle();
    if (existingError || !existing || existing.status !== "draft") fail("/teacher/assignments", "Only your draft assignments can be edited");
    const { error } = await supabase.from("assignments").update(payload).eq("id", existing.id).eq("status", "draft");
    if (error) fail("/teacher/assignments", error.message);
  } else {
    const { error } = await supabase.from("assignments").insert(payload);
    if (error) fail("/teacher/assignments", error.message);
  }
  revalidatePath("/teacher/assignments");
  redirect("/teacher/assignments?notice=Draft+saved" as never);
}

export async function transitionTeacherAssignment(formData: FormData) {
  const parsed = assignmentIdSchema.safeParse(formValues(formData));
  const target = formData.get("target") === "closed" ? "closed" : formData.get("target") === "published" ? "published" : null;
  if (!parsed.success || !target) fail("/teacher/assignments", "Invalid assignment transition");
  const { supabase, userId } = await teacherClient();
  const { data: current, error: currentError } = await supabase.from("assignments").select("id, teacher_assignment_id, status").eq("id", parsed.data.assignment_id).maybeSingle();
  if (currentError || !current || current.status !== "draft" || !await ownTeacherAssignment(supabase, userId, current.teacher_assignment_id)) fail("/teacher/assignments", "Only your draft assignments can be changed");
  const now = new Date().toISOString();
  const { error } = await supabase.from("assignments").update({ status: target, published_at: now }).eq("id", current.id).eq("status", "draft");
  if (error) fail("/teacher/assignments", error.message);
  revalidatePath("/teacher/assignments");
  redirect(`/teacher/assignments?notice=Assignment+${target}` as never);
}

export async function saveTeacherAssessment(formData: FormData) {
  const parsed = assessmentSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/teacher/assessments", parsed.error.issues[0]?.message ?? "Invalid assessment");
  const { supabase, userId } = await teacherClient();
  const teaching = await ownTeacherAssignment(supabase, userId, parsed.data.teacher_assignment_id);
  if (!teaching || (teaching.term_id && teaching.term_id !== parsed.data.term_id)) fail("/teacher/assessments", "Choose one of your valid teaching assignments");
  if (parsed.data.assignment_id) {
    const { data: assignment, error } = await supabase.from("assignments").select("id").eq("id", parsed.data.assignment_id).eq("teacher_assignment_id", teaching.id).eq("term_id", parsed.data.term_id).maybeSingle();
    if (error || !assignment) fail("/teacher/assessments", "The linked assignment must match your teaching assignment and term");
  }
  const { error } = await supabase.from("assessments").insert({ ...parsed.data, assignment_id: parsed.data.assignment_id || null, status: "draft", created_by: userId });
  if (error) fail("/teacher/assessments", error.message);
  revalidatePath("/teacher/assessments");
  redirect("/teacher/assessments?notice=Assessment+draft+saved" as never);
}

export async function saveTeacherAssessmentResults(formData: FormData) {
  const assessmentId = String(formData.get("assessment_id") ?? "");
  const id = assignmentIdSchema.safeParse({ assignment_id: assessmentId });
  if (!id.success) fail("/teacher/assessments", "Invalid assessment");
  const { supabase, userId } = await teacherClient();
  const { data: assessment, error: assessmentError } = await supabase.from("assessments").select("id, teacher_assignment_id, assessment_date, maximum_score, status").eq("id", id.data.assignment_id).maybeSingle();
  if (assessmentError || !assessment || assessment.status !== "draft" || !await ownTeacherAssignment(supabase, userId, assessment.teacher_assignment_id)) fail("/teacher/assessments", "Only your draft assessments can receive results");
  const { data: teaching } = await supabase.from("teacher_assignments").select("class_group_id").eq("id", assessment.teacher_assignment_id).single();
  if (!teaching) fail("/teacher/assessments", "Assessment class is unavailable");
  const { data: roster, error: rosterError } = await supabase.from("class_enrolments").select("student_id").eq("class_group_id", teaching.class_group_id).eq("status", "active").lte("starts_on", assessment.assessment_date).or(`ends_on.is.null,ends_on.gte.${assessment.assessment_date}`);
  if (rosterError) fail("/teacher/assessments", "The eligible roster is unavailable");
  const results = readAssessmentResults(formData, (roster ?? []).map((row) => row.student_id));
  if (!results.success) fail("/teacher/assessments", results.error.issues[0]?.message ?? "Enter a valid result for every eligible student");
  if (results.data.some((result) => result.score > Number(assessment.maximum_score))) fail("/teacher/assessments", "A score cannot exceed the assessment maximum");
  const { error } = await supabase.from("assessment_results").upsert(results.data.map((result) => ({ ...result, recorded_by: userId })), { onConflict: "assessment_id,student_id" });
  if (error) fail("/teacher/assessments", error.message);
  revalidatePath("/teacher/assessments");
  redirect(`/teacher/assessments?assessment=${assessment.id}&notice=Results+draft+saved` as never);
}

export async function publishAssessment(formData: FormData) {
  const parsed = releaseAssessmentSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/admin/operations/assessments", "Invalid assessment");
  const supabase = await requireAdminPermission("assessments.review");
  const { error } = await supabase.from("assessments").update({ status: "published", published_at: new Date().toISOString(), released_at: null }).eq("id", parsed.data.assessment_id).eq("status", "draft");
  if (error) fail("/admin/operations/assessments", error.message);
  revalidatePath("/admin/operations/assessments");
  redirect("/admin/operations/assessments?notice=Assessment+published" as never);
}

export async function releaseAssessmentResults(formData: FormData) {
  const parsed = releaseAssessmentSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("/admin/operations/assessments", "Invalid assessment");
  const supabase = await requireAdminPermission("results.release");
  const now = new Date().toISOString();
  const { error } = await supabase.from("assessments").update({ status: "released", released_at: now, published_at: now }).eq("id", parsed.data.assessment_id).eq("status", "published");
  if (error) fail("/admin/operations/assessments", error.message);
  revalidatePath("/admin/operations/assessments");
  revalidatePath("/student/results");
  redirect("/admin/operations/assessments?notice=Results+released+to+families" as never);
}
