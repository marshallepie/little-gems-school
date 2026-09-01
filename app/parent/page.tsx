import { redirect } from "next/navigation";
import { DashboardCard, EmptyDashboardState, FutureFeatureNote, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { classLabel, firstRelated, fullName } from "@/lib/dashboard-data";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type ChildLink = { student_id: string; relationship: string; is_primary_contact: boolean; students: { admission_number: string; first_name: string; last_name: string; status: string } | { admission_number: string; first_name: string; last_name: string; status: string }[] | null };
type Enrolment = { student_id: string; class_groups: { name: string; level: string; academic_years: { name: string; is_current: boolean } | { name: string; is_current: boolean }[] | null } | { name: string; level: string; academic_years: { name: string; is_current: boolean } | { name: string; is_current: boolean }[] | null }[] | null };

function UnavailableParentDashboard() {
  return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Parent and guardian dashboard" title="Your children at Little Gems"><p>Your school information could not be loaded right now.</p></PortalHeader><UnavailableDashboardState /></main>;
}

export default async function ParentPage() {
  if (await requireRole() !== "parent") redirect("/dashboard");
  const supabase = await createClient();
  const { data: claims, error: claimsError } = await supabase.auth.getClaims();
  if (claimsError) return <UnavailableParentDashboard />;
  const userId = claims?.claims.sub;
  if (!userId) redirect("/login");

  const { data: guardian, error: guardianError } = await supabase.from("guardians").select("id, first_name, last_name").eq("profile_id", userId).maybeSingle();
  if (guardianError) return <UnavailableParentDashboard />;
  if (!guardian) return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Parent and guardian dashboard" title="Your children at Little Gems"><p>Your guardian record is not linked to this account yet.</p></PortalHeader><EmptyDashboardState title="No guardian record linked">Ask an administrator to link your school guardian record before child information can appear here.</EmptyDashboardState></main>;

  const { data: childLinksData, error: childLinksError } = await supabase.from("student_guardians").select("student_id, relationship, is_primary_contact, students(admission_number, first_name, last_name, status)").eq("guardian_id", guardian.id);
  if (childLinksError) return <UnavailableParentDashboard />;
  const childLinks = (childLinksData ?? []) as unknown as ChildLink[];
  const studentIds = childLinks.map((link) => link.student_id);
  const { data: enrolmentData, error: enrolmentError } = studentIds.length ? await supabase.from("class_enrolments").select("student_id, class_groups(name, level, academic_years(name, is_current))").in("student_id", studentIds).eq("status", "active") : { data: [] as Enrolment[], error: null };
  if (enrolmentError) return <UnavailableParentDashboard />;
  const contextsByStudent = new Map<string, Enrolment[]>();
  for (const enrolment of (enrolmentData ?? []) as unknown as Enrolment[]) contextsByStudent.set(enrolment.student_id, [...(contextsByStudent.get(enrolment.student_id) ?? []), enrolment]);

  return <main className="mx-auto max-w-6xl space-y-6">
    <PortalHeader eyebrow="Parent and guardian dashboard" title={`Hello, ${fullName(guardian.first_name, guardian.last_name)}`}><p>Only children linked to your guardian record are shown below.</p></PortalHeader>
    {childLinks.length === 0 ? <EmptyDashboardState title="No linked children">There are no student records linked to your guardian record yet.</EmptyDashboardState> : <section className="grid gap-4 sm:grid-cols-2" aria-label="Your children">{childLinks.map((link) => {
      const child = firstRelated(link.students);
      const contexts = (contextsByStudent.get(link.student_id) ?? []).filter((enrolment) => firstRelated(firstRelated(enrolment.class_groups)?.academic_years)?.is_current === true);
      if (!child) return null;
      return <DashboardCard key={link.student_id} title={fullName(child.first_name, child.last_name)}><p className="text-sm text-slate-700">Admission number: {child.admission_number}</p><p className="text-sm text-slate-700">Relationship: {link.relationship}{link.is_primary_contact ? " · Primary contact" : ""}</p><div><h3 className="font-semibold">Active class</h3>{contexts.length ? <ul className="mt-2 space-y-2">{contexts.map((enrolment, index) => { const classGroup = firstRelated(enrolment.class_groups); const academicYear = firstRelated(classGroup?.academic_years); return <li key={`${link.student_id}-${index}`} className="rounded-lg bg-slate-50 px-3 py-2">{classLabel(classGroup ? { ...classGroup, academicYear: academicYear?.name } : null)}</li>; })}</ul> : <p className="mt-2 text-sm text-slate-600">No active class placement is currently available.</p>}</div></DashboardCard>;
    })}</section>}
    <FutureFeatureNote>Attendance, reports, fees, messaging, and other parent actions are not available in this phase.</FutureFeatureNote>
  </main>;
}
