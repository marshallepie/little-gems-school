import { notFound, redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ChildAssignmentsPage({ params }: { params: Promise<{ studentId: string }> }) {
  if (await requireRole() !== "parent") redirect("/dashboard");
  const supabase = await createClient(); const { studentId } = await params;
  const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: guardian, error: guardianError } = await supabase.from("guardians").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (guardianError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!guardian) notFound();
  const { data: link, error: linkError } = await supabase.from("student_guardians").select("students(first_name, last_name)").eq("guardian_id", guardian.id).eq("student_id", studentId).maybeSingle();
  if (linkError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!link) notFound();
  const child = Array.isArray(link.students) ? link.students[0] : link.students;
  const { data: enrolments, error: enrolmentError } = await supabase.from("class_enrolments").select("class_group_id").eq("student_id", studentId).eq("status", "active").lte("starts_on", new Date().toISOString().slice(0, 10)).or(`ends_on.is.null,ends_on.gte.${new Date().toISOString().slice(0, 10)}`);
  if (enrolmentError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  const classIds = (enrolments ?? []).map((row) => row.class_group_id);
  const { data: assignments, error } = classIds.length ? await supabase.from("assignments").select("id, title, instructions, assigned_on, due_on, teacher_assignments!inner(class_group_id, class_groups(name, level), subjects(code, name))").eq("status", "published").in("teacher_assignments.class_group_id", classIds).order("assigned_on", { ascending: false }) : { data: [], error: null };
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title={`${child?.first_name} ${child?.last_name}'s assignments`}><p>Only published assignments for this linked child’s active class are shown.</p></PortalHeader>{assignments?.length ? <section className="space-y-4">{assignments.map((assignment) => { const teaching = Array.isArray(assignment.teacher_assignments) ? assignment.teacher_assignments[0] : assignment.teacher_assignments; const subject = teaching && (Array.isArray(teaching.subjects) ? teaching.subjects[0] : teaching.subjects); return <article key={assignment.id} className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><h2 className="text-lg font-bold">{assignment.title}</h2><p className="text-sm text-slate-700">{subject ? `${subject.code} — ${subject.name} · ` : ""}Assigned {assignment.assigned_on}{assignment.due_on ? ` · Due ${assignment.due_on}` : ""}</p><p className="mt-3 whitespace-pre-wrap text-slate-700">{assignment.instructions || "No instructions provided."}</p></article>; })}</section> : <EmptyDashboardState title="No published assignments">There are no published assignments for this child’s active class.</EmptyDashboardState>}</main>;
}
