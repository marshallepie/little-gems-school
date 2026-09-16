import Image from "next/image";
import Link from "next/link";
import { redirect } from "next/navigation";
import { updateMyProfile } from "@/app/profile/actions";
import { PortalHeader } from "@/components/dashboard-ui";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
type SearchParams = Promise<{ error?: string }>;

export default async function ProfilePage({ searchParams }: { searchParams: SearchParams }) {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  const { data: profile } = await supabase.from("profiles").select("display_name, phone, address, avatar_path, profile_completed_at, is_active").eq("id", claims.claims.sub).maybeSingle();
  if (!profile?.is_active) redirect("/login");
  const { error } = await searchParams;
  const isComplete = Boolean(profile.profile_completed_at);
  return <main className="mx-auto max-w-xl space-y-6 rounded-lg bg-white p-6 shadow-sm"><PortalHeader role="profile" eyebrow="Account profile" title={isComplete ? "Edit my profile" : "Complete your profile"}><p>{isComplete ? "Update your own basic contact details." : "Please confirm your basic contact details before continuing to your portal."}</p></PortalHeader>{error && <p className="rounded border border-red-300 bg-red-50 p-3" role="alert">{error}</p>}<section className="rounded-lg border border-slate-300 p-4" aria-labelledby="security-heading"><h2 id="security-heading" className="text-lg font-bold">Security</h2><p className="mt-1 text-slate-700">Change your password only while signed in to this account.</p><Link className="mt-3 inline-flex min-h-11 items-center rounded border-2 border-slate-700 px-4 py-2 font-semibold text-slate-950 no-underline hover:bg-slate-100" href="/update-password">Change password</Link></section><form action={updateMyProfile} className="space-y-4" encType="multipart/form-data"><label className="block text-sm font-medium">Full name<input className="mt-1 min-h-11 w-full rounded border p-2" name="display_name" defaultValue={profile.display_name} required maxLength={120} /></label><label className="block text-sm font-medium">Phone<input className="mt-1 min-h-11 w-full rounded border p-2" name="phone" type="tel" defaultValue={profile.phone ?? ""} maxLength={40} /></label><label className="block text-sm font-medium">Address<textarea className="mt-1 min-h-24 w-full rounded border p-2" name="address" defaultValue={profile.address ?? ""} maxLength={500} /></label><fieldset className="rounded border border-slate-300 p-3"><legend className="px-1 text-sm font-semibold">Avatar image (optional)</legend>{profile.avatar_path && <Image alt="Current avatar" className="mb-3 size-20 rounded-full object-cover" height={80} src="/api/profile/avatar" unoptimized width={80} />}<label className="block text-sm font-medium">Upload image<input accept="image/jpeg,image/png,image/webp" className="mt-1 block w-full text-sm" name="avatar" type="file" /></label><p className="mt-1 text-sm text-slate-600">JPEG, PNG, or WebP; maximum 5 MB. Your avatar is private to your signed-in profile.</p>{profile.avatar_path && <label className="mt-2 flex items-center gap-2 text-sm font-medium"><input name="remove_avatar" type="checkbox" /> Remove avatar</label>}</fieldset><div className="flex flex-wrap gap-3"><button className="primary-cta min-h-11 rounded px-4 py-2 font-semibold" type="submit">{isComplete ? "Save changes" : "Save and continue"}</button>{isComplete && <Link className="min-h-11 rounded border-2 border-slate-700 px-4 py-2 font-semibold text-slate-950 no-underline hover:bg-slate-100" href="/dashboard">Back to dashboard</Link>}</div></form></main>;
}
