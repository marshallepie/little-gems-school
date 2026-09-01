import Link from "next/link";
import { DashboardCard, FutureFeatureNote, PortalHeader } from "@/components/dashboard-ui";
import { requireAdminPermission } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";

type CountResult = { count: number | null; error: unknown };

function countLabel(result: CountResult) {
  return result.error ? "Unavailable" : String(result.count ?? 0);
}

export default async function AdminDashboardPage() {
  const supabase = await requireAdminPermission("school_records.read");
  const [students, teachers, classes, currentYear, proprietor] = await Promise.all([
    supabase.from("students").select("id", { count: "exact", head: true }).eq("status", "active"),
    supabase.from("teachers").select("id", { count: "exact", head: true }).eq("employment_status", "active"),
    supabase.from("class_groups").select("id", { count: "exact", head: true }),
    supabase.from("academic_years").select("name").eq("is_current", true).maybeSingle(),
    supabase.rpc("is_proprietor"),
  ]);

  return <main className="mx-auto max-w-6xl space-y-6">
    <PortalHeader eyebrow="Administrator dashboard" title="School at a glance">
      <p>Review the current structure and move into the protected management workspace when you need to maintain approved school records.</p>
    </PortalHeader>
    <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3" aria-label="School summary">
      <DashboardCard title="Active students"><p className="text-3xl font-bold text-[color:var(--gem)]">{countLabel(students)}</p><p className="text-sm text-slate-700">Student records marked active</p></DashboardCard>
      <DashboardCard title="Active teachers"><p className="text-3xl font-bold text-[color:var(--gem)]">{countLabel(teachers)}</p><p className="text-sm text-slate-700">Staff records marked active</p></DashboardCard>
      <DashboardCard title="Class groups"><p className="text-3xl font-bold text-[color:var(--gem)]">{countLabel(classes)}</p><p className="text-sm text-slate-700">{currentYear.data?.name ? `Current year: ${currentYear.data.name}` : "No current academic year is configured."}</p></DashboardCard>
    </section>
    <DashboardCard title="Administration">
      <p className="text-slate-700">School records, relationships, enrolments, and assignments remain in the existing management workspace.</p>
      <div className="flex flex-col gap-3 sm:flex-row">
        <Link className="inline-flex min-h-11 items-center justify-center rounded-lg bg-[color:var(--gem)] px-4 py-2 font-semibold text-white no-underline hover:opacity-90 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[color:var(--gem)]" href="/admin">Open school structure workspace</Link>
        {proprietor.data === true && <Link className="inline-flex min-h-11 items-center justify-center rounded-lg border border-[color:var(--gem)] px-4 py-2 font-semibold no-underline" href="/admin/accounts">Manage account lifecycle</Link>}
      </div>
      {proprietor.data !== true && <p className="text-sm text-slate-600">Account lifecycle management is available only to the active proprietor.</p>}
    </DashboardCard>
    <FutureFeatureNote>Attendance, grades, payments, communications, and other operational workflows are not available in this phase.</FutureFeatureNote>
  </main>;
}
