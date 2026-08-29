"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { roleCodeSchema } from "@/lib/validations/roles";
import { academicYearSchema, classGroupSchema, enrolmentSchema, formValues, guardianSchema, studentGuardianSchema, studentSchema, subjectSchema, teacherAssignmentSchema, teacherSchema, termSchema } from "@/lib/validations/school";

async function requireAdmin() {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) redirect("/login");
  const { data: roles } = await supabase.from("user_roles").select("roles!inner(code)").eq("user_id", userId);
  const allowed = roles?.some((entry) => entry.roles.some((role) => roleCodeSchema.safeParse(role.code).data === "admin"));
  if (!allowed) redirect("/dashboard");
  return supabase;
}

function fail(error: string): never { redirect(`/admin?error=${encodeURIComponent(error)}`); }
async function insert(table: string, values: Record<string, unknown>) {
  const supabase = await requireAdmin();
  const { error } = await supabase.from(table).insert(values);
  if (error) fail(error.message);
  revalidatePath("/admin");
  redirect("/admin?notice=Saved");
}

export async function createStudent(formData: FormData) { const parsed = studentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid student"); await insert("students", { ...parsed.data, date_of_birth: parsed.data.date_of_birth || null }); }
export async function createGuardian(formData: FormData) { const parsed = guardianSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid guardian"); await insert("guardians", { ...parsed.data, email: parsed.data.email || null }); }
export async function createTeacher(formData: FormData) { const parsed = teacherSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid teacher"); await insert("teachers", parsed.data); }
export async function createAcademicYear(formData: FormData) { const parsed = academicYearSchema.safeParse({ ...formValues(formData), is_current: formData.get("is_current") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid academic year"); await insert("academic_years", parsed.data); }
export async function createTerm(formData: FormData) { const parsed = termSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid term"); await insert("terms", parsed.data); }
export async function createClassGroup(formData: FormData) { const parsed = classGroupSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid class"); await insert("class_groups", parsed.data); }
export async function createSubject(formData: FormData) { const parsed = subjectSchema.safeParse({ ...formValues(formData), is_active: formData.get("is_active") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid subject"); await insert("subjects", parsed.data); }
export async function createEnrolment(formData: FormData) { const parsed = enrolmentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid enrolment"); await insert("class_enrolments", parsed.data); }
export async function createStudentGuardian(formData: FormData) { const parsed = studentGuardianSchema.safeParse({ ...formValues(formData), is_primary_contact: formData.get("is_primary_contact") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid guardian relationship"); await insert("student_guardians", parsed.data); }
export async function createTeacherAssignment(formData: FormData) { const parsed = teacherAssignmentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid assignment"); await insert("teacher_assignments", { ...parsed.data, term_id: parsed.data.term_id || null }); }
