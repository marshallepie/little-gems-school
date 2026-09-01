import { redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function StudentAssignmentsPage() {
  if (await requireRole() !== "student") redirect("/dashboard");
  const supabase = await createClient(); const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: student, error: studentError } = await supabase.from("students").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (studentError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!student) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My assignments"><p>Your student record is not linked.</p></PortalHeader><EmptyDashboardState title="No student record">Ask an administrator to link your school record.</EmptyDashboardState></main>;
  const today = new Date().toISOString().slice(0, 10);
  const { data: enrolments, error: enrolmentError } = await supabase.from("class_enrolments").select("class_group_id").eq("student_id", student.id).eq("status", "active").lte("starts_on", today).or(`ends_on.is.null,ends_on.gte.${today}`);
  if (enrolmentError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  const classIds = (enrolments ?? []).map((row) => row.class_group_id);
  const { data: assignments, error } = classIds.length ? await supabase.from("assignments").select("id, title, instructions, assigned_on, due_on, teacher_assignments!inner(class_group_id, subjects(code, name))").eq("status", "published").in("teacher_assignments.class_group_id", classIds).order("assigned_on", { ascending: false }) : { data: [], error: null };
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My assignments"><p>Only published assignments for your active class are shown.</p></PortalHeader>{assignments?.length ? <section className="space-y-4">{assignments.map((assignment) => { const teaching = Array.isArray(assignment.teacher_assignments) ? assignment.teacher_assignments[0] : assignment.teacher_assignments; const subject = teaching && (Array.isArray(teaching.subjects) ? teaching.subjects[0] : teaching.subjects); return <article key={assignment.id} className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><h2 className="text-lg font-bold">{assignment.title}</h2><p className="text-sm text-slate-700">{subject ? `${subject.code} — ${subject.name} · ` : ""}Assigned {assignment.assigned_on}{assignment.due_on ? ` · Due ${assignment.due_on}` : ""}</p><p className="mt-3 whitespace-pre-wrap text-slate-700">{assignment.instructions || "No instructions provided."}</p></article>; })}</section> : <EmptyDashboardState title="No published assignments">There are no published assignments for your active class.</EmptyDashboardState>}</main>;
}
