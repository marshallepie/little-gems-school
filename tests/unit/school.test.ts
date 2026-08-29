import { describe, expect, it } from "vitest";
import { academicYearSchema, studentGuardianSchema, teacherAssignmentSchema, termSchema } from "../../lib/validations/school";

const id = "11111111-1111-4111-8111-111111111111";
describe("Phase 1 school validation", () => {
  it("rejects an academic year with reversed dates", () => {
    expect(academicYearSchema.safeParse({ name: "2026/2027", starts_on: "2027-07-31", ends_on: "2026-09-01", is_current: false }).success).toBe(false);
  });
  it("requires valid relational identifiers", () => {
    expect(studentGuardianSchema.safeParse({ student_id: "not-a-uuid", guardian_id: id, relationship: "Mother", is_primary_contact: true }).success).toBe(false);
    expect(teacherAssignmentSchema.safeParse({ teacher_id: id, class_group_id: id, subject_id: id, term_id: "" }).success).toBe(true);
  });
  it("accepts a correctly bounded term shape before the database verifies year dates", () => {
    expect(termSchema.safeParse({ academic_year_id: id, name: "Term 1", starts_on: "2026-09-01", ends_on: "2026-12-18" }).success).toBe(true);
  });
});
