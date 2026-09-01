import { redirect } from "next/navigation";
import { DashboardCard, EmptyDashboardState, FutureFeatureNote, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { classLabel, firstRelated, fullName, sortAssignments, type AssignmentSummary } from "@/lib/dashboard-data";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type AssignmentRow = { id: string; class_group_id: string; class_groups: { name: string; level: string } | { name: string; level: string }[] | null; subjects: { code: string; name: string } | { code: string; name: string }[] | null; terms: { name: string } | { name: string }[] | null };
type RosterRow = { id: string; class_group_id: string; students: { admission_number: string; first_name: string; last_name: string } | { admission_number: string; first_name: string; last_name: string }[] | null };

function UnavailableTeacherDashboard() {
  return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Teacher dashboard" title="Your teaching overview"><p>Your school information could not be loaded right now.</p></PortalHeader><UnavailableDashboardState /></main>;
}

export default async function TeacherPage() {
  if (await requireRole() !== "teacher") redirect("/dashboard");
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError) return <UnavailableTeacherDashboard />;
  const userId = claims?.claims.sub;
  if (!userId) redirect("/login");

  const { data: teacher, error: teacherError } = await supabase.from("teachers").select("id, first_name, last_name, employment_status").eq("profile_id", userId).maybeSingle();
  if (teacherError) return <UnavailableTeacherDashboard />;
  if (!teacher || teacher.employment_status !== "active") return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Teacher dashboard" title="Your teaching overview"><p>Your active teacher record is not linked to this account.</p></PortalHeader><EmptyDashboardState title="No active teaching record linked">Ask an administrator to link and activate your school teacher record before assignments and class rosters can appear here.</EmptyDashboardState></main>;

  const { data: currentYear, error: currentYearError } = await supabase.from("academic_years").select("id").eq("is_current", true).maybeSingle();
  if (currentYearError) return <UnavailableTeacherDashboard />;
  const { data: assignedClassData, error: assignedClassError } = currentYear ? await supabase.from("class_groups").select("id").eq("academic_year_id", currentYear.id) : { data: [] as { id: string }[], error: null };
  if (assignedClassError) return <UnavailableTeacherDashboard />;
  const assignedClassIds = (assignedClassData ?? []).map((classGroup) => classGroup.id);
  const { data: assignmentsData, error: assignmentsError } = assignedClassIds.length ? await supabase.from("teacher_assignments").select("id, class_group_id, class_groups(name, level), subjects(code, name), terms(name)").eq("teacher_id", teacher.id).in("class_group_id", assignedClassIds) : { data: [] as AssignmentRow[], error: null };
  if (assignmentsError) return <UnavailableTeacherDashboard />;
  const assignmentRows = (assignmentsData ?? []) as unknown as AssignmentRow[];
  const assignments = sortAssignments(assignmentRows.flatMap((assignment): AssignmentSummary[] => {
    const classGroup = firstRelated(assignment.class_groups);
    const subject = firstRelated(assignment.subjects);
    if (!classGroup || !subject) return [];
    return [{ id: assignment.id, classContext: classGroup, subjectName: subject.name, subjectCode: subject.code, termName: firstRelated(assignment.terms)?.name }];
  }));
  const classIds = [...new Set(assignmentRows.map((assignment) => assignment.class_group_id))];
  const { data: rosterData, error: rosterError } = classIds.length ? await supabase.from("class_enrolments").select("id, class_group_id, students(admission_number, first_name, last_name)").in("class_group_id", classIds).eq("status", "active").order("created_at") : { data: [] as RosterRow[], error: null };
  if (rosterError) return <UnavailableTeacherDashboard />;
  const rosterByClass = new Map<string, RosterRow[]>();
  for (const row of (rosterData ?? []) as unknown as RosterRow[]) rosterByClass.set(row.class_group_id, [...(rosterByClass.get(row.class_group_id) ?? []), row]);

  return <main className="mx-auto max-w-6xl space-y-6">
    <PortalHeader eyebrow="Teacher dashboard" title={`Welcome, ${fullName(teacher.first_name, teacher.last_name)}`}><p>Only your active class assignments and the students enrolled in those classes are shown.</p></PortalHeader>
    {assignments.length === 0 ? <EmptyDashboardState title="No assignments yet">There are no class and subject assignments linked to your teacher record.</EmptyDashboardState> : <section className="grid gap-4 lg:grid-cols-2" aria-label="Your assignments">{assignments.map((assignment) => {
      const source = (assignmentsData ?? []).find((row) => row.id === assignment.id) as { class_group_id?: string } | undefined;
      const roster = source?.class_group_id ? rosterByClass.get(source.class_group_id) ?? [] : [];
      return <DashboardCard key={assignment.id} title={classLabel(assignment.classContext)}><p><span className="font-semibold">Subject:</span> {assignment.subjectCode} — {assignment.subjectName}</p>{assignment.termName && <p className="text-sm text-slate-700">Term: {assignment.termName}</p>}<div><h3 className="font-semibold">Active class roster</h3>{roster.length ? <ul className="mt-2 space-y-2" aria-label={`${assignment.classContext.name} roster`}>{roster.map((enrolment) => { const student = firstRelated(enrolment.students); return student ? <li key={enrolment.id} className="rounded-lg bg-slate-50 px-3 py-2"><span className="font-medium">{fullName(student.first_name, student.last_name)}</span><span className="ml-2 text-sm text-slate-600">{student.admission_number}</span></li> : null; })}</ul> : <p className="mt-2 text-sm text-slate-600">No active students are currently listed for this class.</p>}</div></DashboardCard>;
    })}</section>}
    <FutureFeatureNote>Attendance, lesson plans, assessment entry, and messaging are not available in this phase.</FutureFeatureNote>
  </main>;
}
