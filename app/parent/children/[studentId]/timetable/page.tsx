import { notFound, redirect } from "next/navigation";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
const weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];

export default async function ChildTimetablePage({ params }: { params: Promise<{ studentId: string }> }) {
  if (await requireRole() !== "parent") redirect("/dashboard");
  const supabase = await createClient(); const { studentId } = await params;
  const { data: claims } = await supabase.auth.getClaims(); if (!claims?.claims.sub) redirect("/login");
  const { data: guardian, error: guardianError } = await supabase.from("guardians").select("id").eq("profile_id", claims.claims.sub).maybeSingle();
  if (guardianError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child timetable"><p>The timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!guardian) notFound();
  const { data: link, error: linkError } = await supabase.from("student_guardians").select("students(first_name, last_name)").eq("guardian_id", guardian.id).eq("student_id", studentId).maybeSingle();
  if (linkError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child timetable"><p>The timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!link) notFound();
  const child = Array.isArray(link.students) ? link.students[0] : link.students;
  const { data: enrolments, error: enrolmentsError } = await supabase.from("class_enrolments").select("class_group_id, class_groups(academic_years(is_current))").eq("student_id", studentId).eq("status", "active");
  if (enrolmentsError) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child timetable"><p>The timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  const classIds = (enrolments ?? []).flatMap((enrolment) => { const group = Array.isArray(enrolment.class_groups) ? enrolment.class_groups[0] : enrolment.class_groups; const year = group && (Array.isArray(group.academic_years) ? group.academic_years[0] : group.academic_years); return year?.is_current ? [enrolment.class_group_id] : []; });
  const { data: entries, error } = classIds.length ? await supabase.from("timetable_entries").select("id, weekday, session_number, starts_at, ends_at, class_groups(name, level), subjects(code, name), terms(name)").in("class_group_id", classIds).order("weekday").order("session_number") : { data: [], error: null };
  if (error) return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title="Child timetable"><p>The timetable could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-5xl space-y-6"><PortalHeader eyebrow="Parent" title={`${child?.first_name} ${child?.last_name}’s timetable`}><p>Only timetable entries for this linked child are shown when they belong to the child’s current class.</p></PortalHeader>{entries?.length ? <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><ul className="divide-y">{entries.map((entry) => { const group = Array.isArray(entry.class_groups) ? entry.class_groups[0] : entry.class_groups; const subject = Array.isArray(entry.subjects) ? entry.subjects[0] : entry.subjects; return <li key={entry.id} className="py-3"><strong>{weekdays[entry.weekday - 1]} · Session {entry.session_number}</strong><p className="text-sm text-slate-700">{entry.starts_at.slice(0, 5)}–{entry.ends_at.slice(0, 5)} · {group?.level}: {group?.name} · {subject?.code} — {subject?.name}</p></li>; })}</ul></section> : <EmptyDashboardState title="No timetable entries">No current-class timetable entries are available for this child.</EmptyDashboardState>}</main>;
}
