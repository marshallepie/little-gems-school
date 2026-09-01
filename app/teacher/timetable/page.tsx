import { redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
const weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export default async function TeacherTimetablePage() {
  if (await requireRole() !== "teacher") redirect("/dashboard");
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  const { data: teacher, error: teacherError } = await supabase.from("teachers").select("id, employment_status").eq("profile_id", claims.claims.sub).maybeSingle();
  if (teacherError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Teacher" title="My timetable"><p>Your timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!teacher || teacher.employment_status !== "active") return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Teacher" title="My timetable"><p>Your teacher record is not active.</p></PortalHeader><EmptyDashboardState title="No active teacher record">Ask an administrator to link and activate your teacher record.</EmptyDashboardState></main>;
  const { data: entries, error } = await supabase.from("timetable_entries").select("id, weekday, session_number, starts_at, ends_at, class_groups(name, level), subjects(code, name), terms(name)").order("weekday").order("session_number");
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Teacher" title="My timetable"><p>Your timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Teacher" title="My timetable"><p>Only timetable entries permitted for your active teaching assignments are shown.</p></PortalHeader>{entries?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{entries.map((entry) => { const group = Array.isArray(entry.class_groups) ? entry.class_groups[0] : entry.class_groups; const subject = Array.isArray(entry.subjects) ? entry.subjects[0] : entry.subjects; const term = Array.isArray(entry.terms) ? entry.terms[0] : entry.terms; return <li key={entry.id} className="py-3"><strong>{weekdays[entry.weekday - 1]} · Session {entry.session_number}</strong><p className="text-sm text-slate-700">{entry.starts_at.slice(0, 5)}–{entry.ends_at.slice(0, 5)} · {group?.level}: {group?.name} · {subject?.code} — {subject?.name} · {term?.name}</p></li>; })}</ul></section> : <EmptyDashboardState title="No timetable entries">There are no timetable entries assigned to you.</EmptyDashboardState>}</main>;
}
