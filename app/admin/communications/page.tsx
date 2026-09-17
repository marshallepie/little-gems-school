import { saveAnnouncement } from "@/app/communications-actions";
import { AudienceLabels, AudienceOptions, Notice } from "@/components/audience-ui";
import { EmptyDashboardState, PortalHeader, UnavailableDashboardState } from "@/components/dashboard-ui";
import { requireAdminPermission } from "@/lib/auth/require-role";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ notice?: string; error?: string }>;
type Target = { target_kind: string; role_code: string | null; class_group_id: string | null };
function audienceValue(target: Target) { return target.target_kind === "school" ? "school" : target.target_kind === "role" ? `role:${target.role_code}` : `class:${target.class_group_id}`; }

export default async function CommunicationsManagementPage({ searchParams }: { searchParams: SearchParams }) {
  const supabase = await requireAdminPermission("communications.manage");
  const [{ data: classes, error: classError }, { data: announcements, error }, params] = await Promise.all([
    supabase.from("class_groups").select("id, name, level").order("name"),
    supabase.from("announcements").select("id,title,body,status,published_at,announcement_targets(target_kind,role_code,class_group_id)").order("created_at", { ascending: false }).limit(100), searchParams,
  ]);
  if (classError || error) return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader role="admin" eyebrow="Communications" title="Announcements"><p>The management queue could not be loaded.</p></PortalHeader><UnavailableDashboardState /></main>;
  const classRows = classes ?? [];
  return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader role="admin" eyebrow="Communications" title="Internal announcements"><p>Drafts may be edited or published. Published announcements may only be archived; archived records are terminal. All mutations require <code>communications.manage</code>.</p></PortalHeader><Notice {...params} />
    <section className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><h2 className="text-lg font-bold">New announcement</h2><AnnouncementForm classes={classRows} /></section>
    {announcements?.length ? <section className="space-y-4" aria-label="Announcement management queue">{announcements.map((item) => <details key={item.id} className="rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><summary className="cursor-pointer font-bold">{item.title} <span className="ml-2 text-sm font-normal capitalize text-slate-700">{item.status}</span></summary><div className="mt-4 space-y-3"><AudienceLabels classes={classRows} targets={(item.announcement_targets ?? []) as Target[]} /><AnnouncementForm item={{ ...item, announcement_targets: (item.announcement_targets ?? []) as Target[] }} classes={classRows} /></div></details>)}</section> : <EmptyDashboardState title="No announcements yet">Create a draft when an approved school message is ready.</EmptyDashboardState>}</main>;
}
function AnnouncementForm({ classes, item }: { classes: { id: string; name: string; level: string }[]; item?: { id: string; title: string; body: string; status: string; announcement_targets: Target[] } }) {
  if (item?.status === "published") return <form action={saveAnnouncement} className="mt-4"><input type="hidden" name="id" value={item.id} /><input type="hidden" name="title" value={item.title} /><input type="hidden" name="body" value={item.body} />{item.announcement_targets.map((target, index) => <input key={index} type="hidden" name="audiences" value={audienceValue(target)} />)}<input type="hidden" name="intent" value="archive" /><button className="min-h-11 rounded bg-slate-700 px-4 py-3 font-semibold text-white" type="submit">Archive announcement</button></form>;
  if (item?.status === "archived") return <p className="text-sm text-slate-700">Archived announcements are terminal and cannot be changed.</p>;
  return <form action={saveAnnouncement} className="mt-4 space-y-4"><input name="id" type="hidden" value={item?.id ?? ""} /><label className="block font-semibold">Title<input className="mt-1 min-h-11 w-full rounded border p-3" name="title" maxLength={200} required defaultValue={item?.title ?? ""} /></label><label className="block font-semibold">Message<textarea className="mt-1 min-h-28 w-full rounded border p-3" name="body" maxLength={10000} required defaultValue={item?.body ?? ""} /></label><AudienceOptions classes={classes} selected={item?.announcement_targets} /><label className="block font-semibold">Action<select className="mt-1 min-h-11 w-full rounded border bg-white p-3" name="intent" defaultValue="draft"><option value="draft">Save draft</option>{item && <option value="publish">Publish internally</option>}</select></label><button className="primary-cta min-h-11 rounded px-4 py-3 font-semibold" type="submit">{item ? "Save announcement" : "Create draft"}</button></form>;
}
