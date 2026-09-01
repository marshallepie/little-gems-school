import { notFound, redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ChildResultsPage({ params }: { params: Promise<{ studentId: string }> }) {
  if (await requireRole() !== "parent") redirect("/dashboard");
  const supabase = await createClient(); const { studentId } = await params;
  const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: guardian, error: guardianError } = await supabase.from("guardians").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (guardianError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child results"><p>Results could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!guardian) notFound();
  const { data: link, error: linkError } = await supabase.from("student_guardians").select("students(first_name, last_name)").eq("guardian_id", guardian.id).eq("student_id", studentId).maybeSingle();
  if (linkError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child results"><p>Results could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!link) notFound();
  const child = Array.isArray(link.students) ? link.students[0] : link.students;
  const { data: results, error } = await supabase.from("assessment_results").select("id, score, feedback, assessments!inner(title, assessment_date, maximum_score, status, teacher_assignments(subjects(code, name)))").eq("student_id", studentId).eq("assessments.status", "released").order("created_at", { ascending: false });
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child results"><p>Results could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title={`${child?.first_name} ${child?.last_name}'s results`}><p>Only results the school has released for this linked child are shown.</p></PortalHeader>{results?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{results.map((result) => { const assessment = Array.isArray(result.assessments) ? result.assessments[0] : result.assessments; const teaching = assessment && (Array.isArray(assessment.teacher_assignments) ? assessment.teacher_assignments[0] : assessment.teacher_assignments); const subject = teaching && (Array.isArray(teaching.subjects) ? teaching.subjects[0] : teaching.subjects); return <li key={result.id} className="py-3"><strong>{assessment?.title}</strong><p>{result.score}/{assessment?.maximum_score}{subject ? ` · ${subject.code} — ${subject.name}` : ""}</p><p className="text-sm text-slate-700">{assessment?.assessment_date}</p>{result.feedback && <p className="mt-1 text-sm text-slate-700">{result.feedback}</p>}</li>; })}</ul></section> : <EmptyDashboardState title="No released results">There are no released results for this child.</EmptyDashboardState>}</main>;
}
