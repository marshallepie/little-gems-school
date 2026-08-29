import { z } from "zod";

const text = (label: string, max = 120) => z.string().trim().min(1, `${label} is required`).max(max);
const date = (label: string) => z.string().date(`${label} must be a date`);
export const uuid = z.string().uuid("Select a valid record");

export const studentSchema = z.object({ admission_number: text("Admission number", 40), first_name: text("First name"), last_name: text("Last name"), date_of_birth: z.string().date().optional().or(z.literal("")), status: z.enum(["active", "inactive", "graduated"]) });
export const guardianSchema = z.object({ first_name: text("First name"), last_name: text("Last name"), phone: text("Phone", 40), email: z.string().trim().email("Email is invalid").optional().or(z.literal("")) });
export const teacherSchema = z.object({ staff_number: text("Staff number", 40), first_name: text("First name"), last_name: text("Last name"), employment_status: z.enum(["active", "inactive"]) });
export const academicYearSchema = z.object({ name: text("Academic year", 40), starts_on: date("Start date"), ends_on: date("End date"), is_current: z.boolean() }).refine(({ starts_on, ends_on }) => ends_on > starts_on, { message: "End date must be after start date", path: ["ends_on"] });
export const termSchema = z.object({ academic_year_id: uuid, name: text("Term name", 40), starts_on: date("Start date"), ends_on: date("End date") }).refine(({ starts_on, ends_on }) => ends_on > starts_on, { message: "End date must be after start date", path: ["ends_on"] });
export const classGroupSchema = z.object({ academic_year_id: uuid, name: text("Class name", 80), level: text("Level", 80) });
export const subjectSchema = z.object({ code: text("Subject code", 30), name: text("Subject name", 100), is_active: z.boolean() });
export const enrolmentSchema = z.object({ student_id: uuid, class_group_id: uuid, starts_on: date("Start date"), status: z.enum(["active", "withdrawn", "completed"]) });
export const studentGuardianSchema = z.object({ student_id: uuid, guardian_id: uuid, relationship: text("Relationship", 60), is_primary_contact: z.boolean() });
export const teacherAssignmentSchema = z.object({ teacher_id: uuid, class_group_id: uuid, subject_id: uuid, term_id: uuid.optional().or(z.literal("")) });

export function formValues(formData: FormData) {
  return Object.fromEntries(formData.entries());
}
