"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminPermission, requireWebsiteContentEditor } from "@/lib/auth/require-role";
import { cmsDeleteSchema, cmsEventSchema, cmsNewsSchema, cmsPageSchema } from "@/lib/validations/cms";
import { formValues } from "@/lib/validations/school";

type CmsTable = "cms_pages" | "cms_news_posts" | "public_events";
const tableFor = { page: "cms_pages", news: "cms_news_posts", event: "public_events" } as const;
function fail(message: string): never { redirect(`/admin/cms?error=${encodeURIComponent(message)}` as never); }
function paths() { ["/", "/about", "/academics", "/admissions", "/news", "/events", "/contact", "/admin/cms"].forEach((path) => revalidatePath(path)); }

async function saveDraft(table: CmsTable, parsed: { id?: string } & Record<string, unknown>) {
  const supabase = await requireWebsiteContentEditor();
  const { id, ...raw } = parsed;
  const content = { ...raw, status: "draft", published_at: null, published_by: null };
  const result = id
    ? await supabase.from(table).update(content).eq("id", id).eq("status", "draft").select("id").maybeSingle()
    : await supabase.from(table).insert(content);
  if (result.error || (id && !result.data)) fail(result.error?.message ?? "Only your draft content can be edited.");
}

export async function saveCmsPage(formData: FormData) {
  const parsed = cmsPageSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid page");
  await saveDraft("cms_pages", parsed.data); paths(); redirect("/admin/cms?notice=Page+draft+saved" as never);
}
export async function saveCmsNews(formData: FormData) {
  const parsed = cmsNewsSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid news post");
  await saveDraft("cms_news_posts", parsed.data); paths(); redirect("/admin/cms?notice=News+draft+saved" as never);
}
export async function saveCmsEvent(formData: FormData) {
  const parsed = cmsEventSchema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid public event");
  await saveDraft("public_events", parsed.data); paths(); redirect("/admin/cms?notice=Event+draft+saved" as never);
}

/** Clone the active public version into a private replacement draft at the same URL. */
export async function createCmsReplacementDraft(formData: FormData) {
  const parsed = cmsDeleteSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("Invalid CMS record");
  const supabase = await requireWebsiteContentEditor();
  const table = tableFor[parsed.data.kind];
  const { data: published, error: readError } = await supabase.from(table).select("*").eq("id", parsed.data.id).eq("status", "published").maybeSingle();
  if (readError || !published) fail(readError?.message ?? "Only the active published version can be replaced.");
  const copy = Object.fromEntries(Object.entries(published).filter(([key]) => !["id", "created_at", "updated_at", "created_by", "last_edited_by", "published_at", "published_by", "version", "status"].includes(key)));
  const { data: draft, error } = await supabase.from(table).insert({ ...copy, status: "draft", replaces_id: parsed.data.id }).select("id").maybeSingle();
  if (error || !draft) fail(error?.message ?? "Unable to create replacement draft.");
  paths(); redirect(`/admin/cms?notice=Replacement+draft+created&kind=${parsed.data.kind}&edit=${draft.id}` as never);
}

export async function publishCmsItem(formData: FormData) {
  const parsed = cmsDeleteSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("Invalid CMS record");
  const supabase = await requireAdminPermission("website_content.publish");
  const table = tableFor[parsed.data.kind];
  const { data, error } = await supabase.from(table).update({ status: "published" }).eq("id", parsed.data.id).eq("status", "draft").select("id").maybeSingle();
  if (error || !data) fail(error?.message ?? "Only a draft can be published.");
  paths(); redirect("/admin/cms?notice=Content+published+and+prior+version+archived" as never);
}

export async function deleteCmsItem(formData: FormData) {
  const parsed = cmsDeleteSchema.safeParse(formValues(formData));
  if (!parsed.success) fail("Invalid CMS record");
  const supabase = await requireWebsiteContentEditor();
  const table = tableFor[parsed.data.kind];
  const { error, count } = await supabase.from(table).delete({ count: "exact" }).eq("id", parsed.data.id).eq("status", "draft");
  if (error || count !== 1) fail(error?.message ?? "Only your own draft can be deleted.");
  paths(); redirect("/admin/cms?notice=Draft+deleted" as never);
}
