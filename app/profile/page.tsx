import Link from "next/link";
import { redirect } from "next/navigation";
import { updateMyProfile } from "@/app/profile/actions";
import { PortalAccountControls } from "@/components/portal-account-controls";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ error?: string }>;

export default async function ProfilePage({ searchParams }: { searchParams: SearchParams }) {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  const { data: profile } = await supabase.from("profiles")
    .select("display_name, phone, address, avatar_url, profile_completed_at, is_active").eq("id", claims.claims.sub).maybeSingle();
  if (!profile?.is_active) redirect("/login");
  const { error } = await searchParams;
  const isComplete = Boolean(profile.profile_completed_at);

  return <main className="mx-auto max-w-xl space-y-6 rounded-lg bg-white p-6 shadow-sm">
    <header className="space-y-3"><div className="flex flex-wrap items-start justify-between gap-3"><div><p className="font-semibold text-violet-700">Little Gems School</p><h1 className="text-3xl font-bold">{isComplete ? "Edit my profile" : "Complete your profile"}</h1><p className="mt-2 text-slate-700">{isComplete ? "Update your own basic contact details." : "Please confirm your basic contact details before continuing to your portal."}</p></div><PortalAccountControls /></div></header>
    {error && <p className="rounded border border-red-300 bg-red-50 p-3" role="alert">{error}</p>}
    <form action={updateMyProfile} className="space-y-4">
      <label className="block text-sm font-medium">Full name<input className="mt-1 min-h-11 w-full rounded border p-2" name="display_name" defaultValue={profile.display_name} required maxLength={120} /></label>
      <label className="block text-sm font-medium">Phone<input className="mt-1 min-h-11 w-full rounded border p-2" name="phone" type="tel" defaultValue={profile.phone ?? ""} maxLength={40} /></label>
      <label className="block text-sm font-medium">Address<textarea className="mt-1 min-h-24 w-full rounded border p-2" name="address" defaultValue={profile.address ?? ""} maxLength={500} /></label>
      <label className="block text-sm font-medium">Avatar image URL (optional)<input className="mt-1 min-h-11 w-full rounded border p-2" name="avatar_url" type="url" defaultValue={profile.avatar_url ?? ""} placeholder="https://…" /></label>
      <p className="text-sm text-slate-600">Avatar uploads are not configured. You may use an HTTPS image URL, or leave this blank to use the standard initials placeholder.</p>
      <div className="flex flex-wrap gap-3"><button className="primary-cta min-h-11 rounded px-4 py-2 font-semibold" type="submit">{isComplete ? "Save changes" : "Save and continue"}</button>{isComplete && <Link className="min-h-11 rounded border-2 border-slate-700 px-4 py-2 font-semibold text-slate-950 no-underline hover:bg-slate-100" href="/dashboard">Cancel</Link>}</div>
    </form>
  </main>;
}
