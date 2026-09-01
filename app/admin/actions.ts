"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { type AdminPermission, requireAdminPermission } from "@/lib/auth/require-role";
import { academicYearSchema, classGroupSchema, enrolmentSchema, formValues, guardianSchema, studentGuardianSchema, studentSchema, subjectSchema, teacherAssignmentSchema, teacherSchema, termSchema } from "@/lib/validations/school";

function fail(error: string): never { redirect(`/admin?error=${encodeURIComponent(error)}`); }
async function insert(table: string, values: Record<string, unknown>, permission: AdminPermission) {
  const supabase = await requireAdminPermission(permission);
  const { error } = await supabase.from(table).insert(values);
  if (error) fail(error.message);
  revalidatePath("/admin");
  redirect("/admin?notice=Saved");
}

export async function createStudent(formData: FormData) { const parsed = studentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid student"); await insert("students", { ...parsed.data, date_of_birth: parsed.data.date_of_birth || null }, "people.manage"); }
export async function createGuardian(formData: FormData) { const parsed = guardianSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid guardian"); await insert("guardians", { ...parsed.data, email: parsed.data.email || null }, "people.manage"); }
export async function createTeacher(formData: FormData) { const parsed = teacherSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid teacher"); await insert("teachers", parsed.data, "people.manage"); }
export async function createAcademicYear(formData: FormData) { const parsed = academicYearSchema.safeParse({ ...formValues(formData), is_current: formData.get("is_current") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid academic year"); await insert("academic_years", parsed.data, "academic_structure.manage"); }
export async function createTerm(formData: FormData) { const parsed = termSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid term"); await insert("terms", parsed.data, "academic_structure.manage"); }
export async function createClassGroup(formData: FormData) { const parsed = classGroupSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid class"); await insert("class_groups", parsed.data, "academic_structure.manage"); }
export async function createSubject(formData: FormData) { const parsed = subjectSchema.safeParse({ ...formValues(formData), is_active: formData.get("is_active") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid subject"); await insert("subjects", parsed.data, "academic_structure.manage"); }
export async function createEnrolment(formData: FormData) { const parsed = enrolmentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid enrolment"); await insert("class_enrolments", parsed.data, "enrolments.manage"); }
export async function createStudentGuardian(formData: FormData) { const parsed = studentGuardianSchema.safeParse({ ...formValues(formData), is_primary_contact: formData.get("is_primary_contact") === "on" }); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid guardian relationship"); await insert("student_guardians", parsed.data, "people.manage"); }
export async function createTeacherAssignment(formData: FormData) { const parsed = teacherAssignmentSchema.safeParse(formValues(formData)); if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid assignment"); await insert("teacher_assignments", { ...parsed.data, term_id: parsed.data.term_id || null }, "teacher_assignments.manage"); }
