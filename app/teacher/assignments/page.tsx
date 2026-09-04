import { saveTeacherAssignment } from "@/app/operations-actions";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireRole } from "@/lib/auth/require-role";
import { createClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ notice?: string; error?: string }>;

type TeachingAssignment = {
  id: string;
  term_id: string | null;
  class_groups: { name: string; level: string } | { name: string; level: string }[] | null;
  subjects: { code: string; name: string } | { code: string; name: string }[] | null;
};

type Term = { id: string; name: string };

type Assignment = {
  id: string;
  teacher_assignment_id: string;
  term_id: string;
  title: string;
  instructions: string;
  assigned_on: string;
  due_on: string | null;
  status: string;
};

function TeachingAssignmentOptions({ teaching }: { teaching: TeachingAssignment[] }) {
  return <>{teaching.map((row) => {
    const group = Array.isArray(row.class_groups) ? row.class_groups[0] : row.class_groups;
    const subject = Array.isArray(row.subjects) ? row.subjects[0] : row.subjects;
    return <option key={row.id} value={row.id}>{group?.level}: {group?.name} · {subject?.code} — {subject?.name}</option>;
  })}</>;
}

function AssignmentFields({ teaching, terms, assignment }: { teaching: TeachingAssignment[]; terms: Term[]; assignment?: Assignment }) {
  return <>
    {assignment && <input type="hidden" name="assignment_id" value={assignment.id} />}
    <label className="text-sm font-medium">Teaching assignment
      <select required name="teacher_assignment_id" defaultValue={assignment?.teacher_assignment_id ?? ""} className="mt-1 min-h-11 w-full rounded border p-2">
        <option value="">Select…</option><TeachingAssignmentOptions teaching={teaching} />
      </select>
    </label>
    <label className="text-sm font-medium">Term
      <select required name="term_id" defaultValue={assignment?.term_id ?? ""} className="mt-1 min-h-11 w-full rounded border p-2">
        <option value="">Select…</option>{terms.map((term) => <option key={term.id} value={term.id}>{term.name}</option>)}
      </select>
    </label>
    <label className="text-sm font-medium md:col-span-2">Title<input required name="title" maxLength={200} defaultValue={assignment?.title} className="mt-1 min-h-11 w-full rounded border p-2" /></label>
    <label className="text-sm font-medium md:col-span-2">Instructions<textarea name="instructions" maxLength={10000} defaultValue={assignment?.instructions} className="mt-1 min-h-24 w-full rounded border p-2" /></label>
    <label className="text-sm font-medium">Assigned on<input required type="date" name="assigned_on" defaultValue={assignment?.assigned_on} className="mt-1 min-h-11 w-full rounded border p-2" /></label>
    <label className="text-sm font-medium">Due on (optional)<input type="date" name="due_on" defaultValue={assignment?.due_on ?? ""} className="mt-1 min-h-11 w-full rounded border p-2" /></label>
  </>;
}

export default async function TeacherAssignmentsPage({ searchParams }: { searchParams: SearchParams }) {
  if (await requireRole() !== "teacher") redirect("/dashboard");
  const supabase = await createClient();
  const [{ data: claims }, params] = await Promise.all([supabase.auth.getClaims(), searchParams]);
  if (!claims?.claims.sub) redirect("/login");
  const { data: teacher, error: teacherError } = await supabase.from("teachers").select("id, employment_status").eq("profile_id", claims.claims.sub).maybeSingle();
  if (teacherError) return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Teacher" title="Assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  if (!teacher || teacher.employment_status !== "active") return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Teacher" title="Assignments"><p>Your teacher record is not active.</p></PortalHeader><EmptyDashboardState title="No active teacher record">Ask an administrator to link and activate your teacher record.</EmptyDashboardState></main>;

  const [{ data: teaching, error: teachingError }, { data: assignments, error: assignmentsError }, { data: terms, error: termsError }] = await Promise.all([
    supabase.from("teacher_assignments").select("id, term_id, class_groups(name, level), subjects(code, name)").eq("teacher_id", teacher.id).order("created_at"),
    supabase.from("assignments").select("id, teacher_assignment_id, term_id, title, instructions, assigned_on, due_on, status").order("assigned_on", { ascending: false }),
    supabase.from("terms").select("id, name").order("starts_on"),
  ]);
  if (teachingError || assignmentsError || termsError) return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Teacher" title="Assignments"><p>Assignments could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  const teachingRows = (teaching ?? []) as TeachingAssignment[];
  const termRows = (terms ?? []) as Term[];
  const assignmentRows = (assignments ?? []) as Assignment[];

  return <main className="mx-auto max-w-6xl space-y-6">
    <PortalHeader eyebrow="Teacher" title="Assignments"><p>Create and edit only your own drafts. An administrator with <code>assessments.review</code> reviews, publishes, or closes assignments.</p></PortalHeader>
    {params.notice && <p role="status" className="rounded border border-green-300 bg-green-50 p-3">{params.notice.replaceAll("+", " ")}</p>}
    {params.error && <p role="alert" className="rounded border border-red-300 bg-red-50 p-3">{params.error}</p>}
    <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
      <h2 className="text-lg font-bold">New draft assignment</h2>
      {teachingRows.length ? <form action={saveTeacherAssignment} className="mt-4 grid gap-4 md:grid-cols-2"><AssignmentFields teaching={teachingRows} terms={termRows} /><button className="primary-cta min-h-11 rounded px-4 font-semibold md:col-span-2" type="submit">Save draft</button></form> : <EmptyDashboardState title="No teaching assignments">An administrator must create a teaching assignment before you can author work.</EmptyDashboardState>}
    </section>
    {assignmentRows.length ? <section aria-label="My assignments" className="space-y-4">{assignmentRows.map((assignment) => <article key={assignment.id} className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
      <h2 className="text-lg font-bold">{assignment.title}</h2>
      <p className="text-sm text-slate-700">Assigned {assignment.assigned_on}{assignment.due_on ? ` · Due ${assignment.due_on}` : ""} · <span className="font-semibold capitalize">{assignment.status}</span></p>
      <p className="mt-3 whitespace-pre-wrap text-slate-700">{assignment.instructions || "No instructions provided."}</p>
      {assignment.status === "draft" && <details className="mt-4 rounded border p-3"><summary className="cursor-pointer font-semibold">Edit this draft</summary><form action={saveTeacherAssignment} className="mt-4 grid gap-4 md:grid-cols-2"><AssignmentFields teaching={teachingRows} terms={termRows} assignment={assignment} /><button className="primary-cta min-h-11 rounded px-4 font-semibold md:col-span-2" type="submit">Save draft changes</button></form></details>}
    </article>)}</section> : <EmptyDashboardState title="No assignments yet">Save a draft assignment to see it here.</EmptyDashboardState>}
  </main>;
}
