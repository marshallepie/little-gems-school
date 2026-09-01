import { describe, expect, it } from "vitest";
import { classLabel, fullName, sortAssignments } from "../../lib/dashboard-data";

describe("dashboard data helpers", () => {
  it("renders readable identity and class context", () => {
    expect(fullName(" Ada ", " Lovelace ")).toBe("Ada Lovelace");
    expect(classLabel({ level: "Year 2", name: "Sapphires", academicYear: "2026/2027" })).toBe("Year 2 — Sapphires (2026/2027)");
    expect(classLabel(null)).toBe("Class placement is not currently available.");
  });

  it("orders teacher assignment summaries by class and subject without mutating input", () => {
    const assignments = [
      { id: "2", classContext: { level: "Year 2", name: "B" }, subjectName: "Maths", subjectCode: "MAT" },
      { id: "1", classContext: { level: "Year 1", name: "A" }, subjectName: "English", subjectCode: "ENG" },
    ];
    expect(sortAssignments(assignments).map((assignment) => assignment.id)).toEqual(["1", "2"]);
    expect(assignments.map((assignment) => assignment.id)).toEqual(["2", "1"]);
  });
});
