import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const PRIVATE_NO_STORE = { "Cache-Control": "private, no-store" };
function signedRedirect(url: string) { return new Response(null, { status: 302, headers: { ...PRIVATE_NO_STORE, Location: url } }); }

export async function GET() {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims.sub;
  if (!userId) return new Response(null, { status: 401, headers: PRIVATE_NO_STORE });
  const { data: profile } = await supabase.from("profiles").select("avatar_path,is_active").eq("id", userId).maybeSingle();
  if (!profile?.is_active || !profile.avatar_path) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  const { data: signed, error } = await createAdminClient().storage.from("profile-avatars").createSignedUrl(profile.avatar_path, 60);
  if (error || !signed?.signedUrl) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  return signedRedirect(signed.signedUrl);
}
