import { createClient } from "@/lib/supabase/server";

type NewsPost = { id: string; slug: string; title: string; excerpt: string; body: string; published_at: string | null };
type PublicEvent = { id: string; slug: string; title: string; summary: string; details: string; starts_at: string; ends_at: string };
type PublicPageRecord = { id: string; slug: string; title: string; summary: string; body: string };

async function publicClient() {
  try { return await createClient(); } catch { return null; }
}

export async function getPublishedPage(slug: string): Promise<PublicPageRecord | null> {
  const supabase = await publicClient();
  if (!supabase) return null;
  const { data, error } = await supabase.from("cms_pages").select("id, slug, title, summary, body").eq("slug", slug).eq("status", "published").lte("published_at", new Date().toISOString()).maybeSingle();
  return error ? null : data;
}

export async function getPublishedNews(limit = 24): Promise<NewsPost[]> {
  const supabase = await publicClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("cms_news_posts").select("id, slug, title, excerpt, body, published_at").eq("status", "published").lte("published_at", new Date().toISOString()).order("published_at", { ascending: false }).limit(limit);
  return error ? [] : data ?? [];
}

export async function getPublishedEvents(limit = 24): Promise<PublicEvent[]> {
  const supabase = await publicClient();
  if (!supabase) return [];
  const { data, error } = await supabase.from("public_events").select("id, slug, title, summary, details, starts_at, ends_at").eq("status", "published").lte("published_at", new Date().toISOString()).order("starts_at").limit(limit);
  return error ? [] : data ?? [];
}
