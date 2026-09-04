import { reviewAssignment } from "@/app/operations-actions";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireAdminPermission } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ notice?: string; error?: string }>;

export default async function AssignmentOperationsPage({ searchParams }: { searchParams: SearchParams }) {
  const supabase = await requireAdminPermission("assessments.review");
  const [{ data: assignments, error }, params] = await Promise.all([
    supabase.from("assignments").select("id, title, instructions, assigned_on, due_on, status, teacher_assignments(class_groups(name, level), subjects(code, name))").order("assigned_on", { ascending: false }).limit(100),
    searchParams,
  ]);
  if (error) return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader eyebrow="Operations" title="Assignment review"><p>The assignment review queue could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  return <main className="mx-auto max-w-6xl space-y-6">
    <PortalHeader eyebrow="Administrator operations" title="Assignment review"><p>Review teacher drafts. Publishing and closing require <code>assessments.review</code> and use your normal authenticated session.</p></PortalHeader>
    {params.notice && <p role="status" className="rounded border border-green-300 bg-green-50 p-3">{params.notice.replaceAll("+", " ")}</p>}
    {params.error && <p role="alert" className="rounded border border-red-300 bg-red-50 p-3">{params.error}</p>}
    {assignments?.length ? <div className="space-y-4">{assignments.map((assignment) => {
      const teaching = Array.isArray(assignment.teacher_assignments) ? assignment.teacher_assignments[0] : assignment.teacher_assignments;
      const group = teaching && (Array.isArray(teaching.class_groups) ? teaching.class_groups[0] : teaching.class_groups);
      const subject = teaching && (Array.isArray(teaching.subjects) ? teaching.subjects[0] : teaching.subjects);
      return <section key={assignment.id} className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200">
        <div className="flex flex-wrap justify-between gap-3"><div><h2 className="text-lg font-bold">{assignment.title}</h2><p className="text-sm text-slate-700">Assigned {assignment.assigned_on}{assignment.due_on ? ` · Due ${assignment.due_on}` : ""} · <span className="font-semibold capitalize">{assignment.status}</span>{group ? ` · ${group.level}: ${group.name}` : ""}{subject ? ` · ${subject.code}` : ""}</p></div>
          {(assignment.status === "draft" || assignment.status === "published") && <div className="flex gap-2">{assignment.status === "draft" && <form action={reviewAssignment}><input type="hidden" name="assignment_id" value={assignment.id} /><input type="hidden" name="target" value="published" /><button className="primary-cta min-h-11 rounded px-3 font-semibold" type="submit">Publish</button></form>}<form action={reviewAssignment}><input type="hidden" name="assignment_id" value={assignment.id} /><input type="hidden" name="target" value="closed" /><button className="min-h-11 rounded border px-3 font-semibold" type="submit">Close</button></form></div>}
        </div>
        <p className="mt-3 whitespace-pre-wrap text-slate-700">{assignment.instructions || "No instructions provided."}</p>
      </section>;
    })}</div> : <EmptyDashboardState title="No assignments to review">Teacher assignment drafts will appear here when available.</EmptyDashboardState>}
  </main>;
}
