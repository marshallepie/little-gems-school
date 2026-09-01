import { redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function StudentAttendancePage() {
  if (await requireRole() !== "student") redirect("/dashboard");
  const supabase = await createClient(); const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: student, error: studentError } = await supabase.from("students").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (studentError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My attendance"><p>Your attendance could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!student) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My attendance"><p>Your student record is not linked.</p></PortalHeader><EmptyDashboardState title="No student record">Ask an administrator to link your school record.</EmptyDashboardState></main>;
  const { data: records, error } = await supabase.from("attendance_records").select("id, status, attendance_sessions!inner(attendance_date, session_number, status, student_visible, class_groups(name, level))").eq("student_id", student.id).in("attendance_sessions.status", ["submitted", "corrected"]).eq("attendance_sessions.student_visible", true).order("recorded_at", { ascending: false });
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My attendance"><p>Your attendance could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My attendance"><p>Only submitted registers that the school has made visible to you are shown.</p></PortalHeader>{records?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{records.map((record) => { const session = Array.isArray(record.attendance_sessions) ? record.attendance_sessions[0] : record.attendance_sessions; const group = session && (Array.isArray(session.class_groups) ? session.class_groups[0] : session.class_groups); return <li key={record.id} className="py-3"><strong className="capitalize">{record.status}</strong><p className="text-sm text-slate-700">{session?.attendance_date} · Session {session?.session_number} · {group?.level}: {group?.name}</p></li>; })}</ul></section> : <EmptyDashboardState title="No visible attendance">No submitted attendance has been made visible to you.</EmptyDashboardState>}</main>;
}
