import { redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
const weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export default async function StudentTimetablePage() {
  if (await requireRole() !== "student") redirect("/dashboard");
  const supabase = await createClient(); const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: student, error: studentError } = await supabase.from("students").select("first_name, last_name").eq("profile_id", claims.claims.sub).maybeSingle();
  if (studentError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My timetable"><p>Your timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!student) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My timetable"><p>Your student record is not linked.</p></PortalHeader><EmptyDashboardState title="No student record">Ask an administrator to link your school record.</EmptyDashboardState></main>;
  const { data: entries, error } = await supabase.from("timetable_entries").select("id, weekday, session_number, starts_at, ends_at, class_groups(name, level), subjects(code, name)").order("weekday").order("session_number");
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My timetable"><p>Your timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Student" title="My timetable"><p>Only timetable entries for your current class are shown.</p></PortalHeader>{entries?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{entries.map((entry) => { const group = Array.isArray(entry.class_groups) ? entry.class_groups[0] : entry.class_groups; const subject = Array.isArray(entry.subjects) ? entry.subjects[0] : entry.subjects; return <li key={entry.id} className="py-3"><strong>{weekdays[entry.weekday - 1]} · Session {entry.session_number}</strong><p className="text-sm text-slate-700">{entry.starts_at.slice(0, 5)}–{entry.ends_at.slice(0, 5)} · {group?.level}: {group?.name} · {subject?.code} — {subject?.name}</p></li>; })}</ul></section> : <EmptyDashboardState title="No timetable entries">No current-class timetable entries are available.</EmptyDashboardState>}</main>;
}
