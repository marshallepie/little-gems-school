export type ClassContext = {
  name: string;
  level: string;
  academicYear?: string | null;
};

export type AssignmentSummary = {
  id: string;
  classContext: ClassContext;
  subjectName: string;
  subjectCode: string;
  termName?: string | null;
};

export function firstRelated<T>(value: T | T[] | null | undefined) {
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

export function fullName(firstName: string, lastName: string) {
  return `${firstName} ${lastName}`.replace(/\s+/g, " ").trim();
}

export function classLabel(classContext: ClassContext | null | undefined) {
  if (!classContext) return "Class placement is not currently available.";
  return `${classContext.level} — ${classContext.name}${classContext.academicYear ? ` (${classContext.academicYear})` : ""}`;
}

export function sortAssignments(assignments: AssignmentSummary[]) {
  return [...assignments].sort((left, right) =>
    `${left.classContext.level} ${left.classContext.name} ${left.subjectName}`.localeCompare(
      `${right.classContext.level} ${right.classContext.name} ${right.subjectName}`,
    ),
  );
}
