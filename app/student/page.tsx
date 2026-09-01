import { redirect } from "next/navigation";
import { DashboardCard, EmptyDashboardState, FutureFeatureNote, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { classLabel, firstRelated, fullName } from "@/lib/dashboard-data";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type Enrolment = { id: string; class_groups: { name: string; level: string; academic_years: { name: string; is_current: boolean } | { name: string; is_current: boolean }[] | null } | { name: string; level: string; academic_years: { name: string; is_current: boolean } | { name: string; is_current: boolean }[] | null }[] | null };

function UnavailableStudentDashboard() {
  return <main className="mx-auto max-w-4xl space-y-6"><PortalHeader eyebrow="Student dashboard" title="Your school overview"><p>Your school information could not be loaded right now.</p></PortalHeader><UnavailableDashboardState /></main>;
}

export default async function StudentPage() {
  if (await requireRole() !== "student") redirect("/dashboard");
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError) return <UnavailableStudentDashboard />;
  const userId = claims?.claims.sub;
  if (!userId) redirect("/login");

  const { data: student, error: studentError } = await supabase.from("students").select("id, admission_number, first_name, last_name, status").eq("profile_id", userId).maybeSingle();
  if (studentError) return <UnavailableStudentDashboard />;
  if (!student) return <main className="mx-auto max-w-4xl space-y-6"><PortalHeader eyebrow="Student dashboard" title="Your school overview"><p>Your student record is not linked to this account yet.</p></PortalHeader><EmptyDashboardState title="No student record linked">Ask an administrator to link your school student record before your class information can appear here.</EmptyDashboardState></main>;

  const { data: enrolmentsData, error: enrolmentsError } = await supabase.from("class_enrolments").select("id, class_groups(name, level, academic_years(name, is_current))").eq("student_id", student.id).eq("status", "active");
  if (enrolmentsError) return <UnavailableStudentDashboard />;
  const enrolments = (enrolmentsData ?? []) as unknown as Enrolment[];
  const currentEnrolments = enrolments.filter((enrolment) => firstRelated(firstRelated(enrolment.class_groups)?.academic_years)?.is_current === true);
  return <main className="mx-auto max-w-4xl space-y-6">
    <PortalHeader eyebrow="Student dashboard" title={`Hello, ${fullName(student.first_name, student.last_name)}`}><p>This is your own school identity and active class information.</p></PortalHeader>
    <DashboardCard title="My school details"><dl className="grid gap-3 sm:grid-cols-2"><div><dt className="text-sm font-semibold text-slate-600">Admission number</dt><dd className="mt-1">{student.admission_number}</dd></div><div><dt className="text-sm font-semibold text-slate-600">Status</dt><dd className="mt-1 capitalize">{student.status}</dd></div></dl></DashboardCard>
    <DashboardCard title="My active class">{currentEnrolments.length ? <ul className="space-y-2">{currentEnrolments.map((enrolment) => { const classGroup = firstRelated(enrolment.class_groups); const academicYear = firstRelated(classGroup?.academic_years); return <li key={enrolment.id} className="rounded-lg bg-slate-50 px-3 py-2">{classLabel(classGroup ? { ...classGroup, academicYear: academicYear?.name } : null)}</li>; })}</ul> : <p className="text-slate-700">No active class placement is currently available.</p>}</DashboardCard>
    <FutureFeatureNote>Lessons, assignments, attendance, and results are not available in this phase.</FutureFeatureNote>
  </main>;
}
