import { notFound, redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function ChildAttendancePage({ params }: { params: Promise<{ studentId: string }> }) {
  if (await requireRole() !== "parent") redirect("/dashboard");
  const supabase = await createClient(); const { studentId } = await params;
  const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: guardian, error: guardianError } = await supabase.from("guardians").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (guardianError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child attendance"><p>Attendance could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!guardian) notFound();
  const { data: link, error: linkError } = await supabase.from("student_guardians").select("students(first_name, last_name)").eq("guardian_id", guardian.id).eq("student_id", studentId).maybeSingle();
  if (linkError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child attendance"><p>Attendance could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!link) notFound();
  const child = Array.isArray(link.students) ? link.students[0] : link.students;
  const { data: records, error } = await supabase.from("attendance_records").select("id, status, attendance_sessions!inner(attendance_date, session_number, status, class_groups(name, level))").eq("student_id", studentId).in("attendance_sessions.status", ["submitted", "corrected"]).order("recorded_at", { ascending: false });
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child attendance"><p>Attendance could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title={`${child?.first_name} ${child?.last_name}'s attendance`}><p>Only submitted attendance for this linked child is shown.</p></PortalHeader>{records?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{records.map((record) => { const session = Array.isArray(record.attendance_sessions) ? record.attendance_sessions[0] : record.attendance_sessions; const group = session && (Array.isArray(session.class_groups) ? session.class_groups[0] : session.class_groups); return <li key={record.id} className="py-3"><strong className="capitalize">{record.status}</strong><p className="text-sm text-slate-700">{session?.attendance_date} · Session {session?.session_number} · {group?.level}: {group?.name} · {session?.status}</p></li>; })}</ul></section> : <EmptyDashboardState title="No submitted attendance">There is no submitted attendance available for this child.</EmptyDashboardState>}</main>;
}
