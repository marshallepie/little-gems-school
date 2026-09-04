"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminPermission } from "@/lib/auth/require-role";
import { cmsDeleteSchema, cmsEventSchema, cmsNewsSchema, cmsPageSchema } from "@/lib/validations/cms";
import { formValues } from "@/lib/validations/school";

function fail(message: string): never { redirect(`/admin/cms?error=${encodeURIComponent(message)}` as never); }
function paths() { ["/", "/about", "/academics", "/admissions", "/news", "/events", "/contact", "/admin/cms"].forEach((path) => revalidatePath(path)); }

export async function saveCmsPage(formData: FormData) {
  const parsed = cmsPageSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid page");
  const supabase = await requireAdminPermission("website.manage");
  const { id, status, ...content } = parsed.data;
  const payload = { ...content, status, published_at: status === "published" ? new Date().toISOString() : null };
  const result = id ? await supabase.from("cms_pages").update(payload).eq("id", id) : await supabase.from("cms_pages").insert(payload);
  if (result.error) fail(result.error.message);
  paths(); redirect("/admin/cms?notice=Page+saved" as never);
}

export async function saveCmsNews(formData: FormData) {
  const parsed = cmsNewsSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid news post");
  const supabase = await requireAdminPermission("website.manage");
  const { id, published_at, status, ...content } = parsed.data;
  const payload = { ...content, status, published_at: status === "published" ? (published_at || new Date().toISOString()) : null };
  const result = id ? await supabase.from("cms_news_posts").update(payload).eq("id", id) : await supabase.from("cms_news_posts").insert(payload);
  if (result.error) fail(result.error.message);
  paths(); redirect("/admin/cms?notice=News+post+saved" as never);
}

export async function saveCmsEvent(formData: FormData) {
  const parsed = cmsEventSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid public event");
  const supabase = await requireAdminPermission("website.manage");
  const { id, status, ...content } = parsed.data;
  const payload = { ...content, status, published_at: status === "published" ? new Date().toISOString() : null };
  const result = id ? await supabase.from("public_events").update(payload).eq("id", id) : await supabase.from("public_events").insert(payload);
  if (result.error) fail(result.error.message);
  paths(); redirect("/admin/cms?notice=Public+event+saved" as never);
}

export async function deleteCmsItem(formData: FormData) {
  const parsed = cmsDeleteSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("Invalid CMS record");
  const supabase = await requireAdminPermission("website.manage");
  const table = { page: "cms_pages", news: "cms_news_posts", event: "public_events" }[parsed.data.kind];
  const { error } = await supabase.from(table).delete().eq("id", parsed.data.id);
  if (error) fail(error.message);
  paths(); redirect("/admin/cms?notice=Content+deleted" as never);
}
