import { redirect } from "next/navigation";
import { updateMyProfile } from "@/app/profile/actions";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ error?: string }>;

export default async function ProfilePage({ searchParams }: { searchParams: SearchParams }) {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  const { data: profile } = await supabase.from("profiles")
    .select("display_name, phone, address, avatar_url").eq("id", claims.claims.sub).maybeSingle();
  if (!profile) redirect("/login");
  const { error } = await searchParams;

  return <main className="mx-auto max-w-xl space-y-6 rounded-lg bg-white p-6 shadow-sm">
    <header><p className="font-semibold text-violet-700">Little Gems School</p><h1 className="text-3xl font-bold">Complete your profile</h1><p className="mt-2 text-slate-700">Please confirm your basic contact details before continuing to your portal.</p></header>
    {error && <p className="rounded border border-red-300 bg-red-50 p-3" role="alert">{error}</p>}
    <form action={updateMyProfile} className="space-y-4">
      <label className="block text-sm font-medium">Full name<input className="mt-1 min-h-11 w-full rounded border p-2" name="display_name" defaultValue={profile.display_name} required maxLength={120} /></label>
      <label className="block text-sm font-medium">Phone<input className="mt-1 min-h-11 w-full rounded border p-2" name="phone" type="tel" defaultValue={profile.phone ?? ""} maxLength={40} /></label>
      <label className="block text-sm font-medium">Address<textarea className="mt-1 min-h-24 w-full rounded border p-2" name="address" defaultValue={profile.address ?? ""} maxLength={500} /></label>
      <label className="block text-sm font-medium">Avatar image URL (optional)<input className="mt-1 min-h-11 w-full rounded border p-2" name="avatar_url" type="url" defaultValue={profile.avatar_url ?? ""} placeholder="https://…" /></label>
      <p className="text-sm text-slate-600">Avatar uploads are not configured. You may use an HTTPS image URL, or leave this blank to use the standard initials placeholder.</p>
      <button className="min-h-11 rounded bg-violet-700 px-4 py-2 font-semibold text-white" type="submit">Save and continue</button>
    </form>
  </main>;
}
