import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import { createAdminClient } from "@/lib/supabase/admin";

const tables = { page: "cms_pages", news: "cms_news_posts", event: "public_events" } as const;
type PublicMediaKind = keyof typeof tables;
const isPublicMediaKind = (kind: string): kind is PublicMediaKind => Object.hasOwn(tables, kind);
const idPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
// Signed URL authorization must be checked on every request, including redirects.
const PRIVATE_NO_STORE = { "Cache-Control": "private, no-store" };
function signedRedirect(url: string) { return new Response(null, { status: 302, headers: { ...PRIVATE_NO_STORE, Location: url } }); }

export async function GET(_: Request, { params }: { params: Promise<{ kind: string; id: string }> }) {
  const { kind, id } = await params;
  if (!isPublicMediaKind(kind) || !idPattern.test(id)) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  // Use an anon client, not request cookies: an editor session must not turn a
  // draft image into a publicly retrievable object.
  const publicClient = createSupabaseClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data } = await publicClient.from(tables[kind as keyof typeof tables]).select("image_path").eq("id", id).eq("status", "published").lte("published_at", new Date().toISOString()).maybeSingle();
  if (!data?.image_path) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  const { data: signed, error } = await createAdminClient().storage.from("cms-images").createSignedUrl(data.image_path, 300);
  if (error || !signed?.signedUrl) return new Response(null, { status: 404, headers: PRIVATE_NO_STORE });
  return signedRedirect(signed.signedUrl);
}
