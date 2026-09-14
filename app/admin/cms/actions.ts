"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireAdminPermission, requireWebsiteContentEditor } from "@/lib/auth/require-role";
import { imagePath, validateImageUpload } from "@/lib/image-upload";
import { cleanupStorageObject } from "@/lib/storage-cleanup";
import { createAdminClient } from "@/lib/supabase/admin";
import { cmsDeleteSchema, cmsEventSchema, cmsNewsSchema, cmsPageSchema } from "@/lib/validations/cms";
import { formValues } from "@/lib/validations/school";

type CmsTable = "cms_pages" | "cms_news_posts" | "public_events";
type CmsKind = "page" | "news" | "event";
const tableFor = { page: "cms_pages", news: "cms_news_posts", event: "public_events" } as const;
function fail(message: string): never { redirect(`/admin/cms?error=${encodeURIComponent(message)}` as never); }
function paths() { ["/", "/about", "/academics", "/admissions", "/news", "/events", "/contact", "/admin/cms"].forEach((path) => revalidatePath(path)); }

async function saveDraft(table: CmsTable, parsed: { id?: string } & Record<string, unknown>) {
  const supabase = await requireWebsiteContentEditor();
  const { id, ...raw } = parsed;
  const content = { ...raw, status: "draft", published_at: null, published_by: null };
  const result = id
    ? await supabase.from(table).update(content).eq("id", id).eq("status", "draft").select("id,image_path").maybeSingle()
    : await supabase.from(table).insert(content).select("id,image_path").maybeSingle();
  if (result.error || !result.data) fail(result.error?.message ?? "Only your draft content can be edited.");
  return { supabase, item: result.data as { id: string; image_path: string | null } };
}

async function syncDraftImage(table: CmsTable, kind: CmsKind, formData: FormData, item: { id: string; image_path: string | null }, supabase: Awaited<ReturnType<typeof requireWebsiteContentEditor>>) {
  const image = await validateImageUpload(formData.get("image"));
  const removeImage = formData.get("remove_image") === "on";
  if (!image && !removeImage) return;
  if (image && removeImage) fail("Choose either a replacement image or remove the current image.");
  const admin = createAdminClient();
  if (!image) {
    const { error } = await supabase.from(table).update({ image_path: null }).eq("id", item.id).eq("status", "draft");
    if (error) fail(error.message);
    if (item.image_path) await cleanupStorageObject(admin.storage.from("cms-images"), "cms-images", item.image_path, "remove");
    return;
  }
  const path = imagePath("content", item.id, image.type as "image/jpeg" | "image/png" | "image/webp", kind);
  const { error: uploadError } = await admin.storage.from("cms-images").upload(path, image, { contentType: image.type, upsert: false });
  if (uploadError) fail("Image upload failed. Please try again.");
  const { error: updateError } = await supabase.from(table).update({ image_path: path }).eq("id", item.id).eq("status", "draft");
  if (updateError) {
    await cleanupStorageObject(admin.storage.from("cms-images"), "cms-images", path, "rollback");
    fail(updateError.message);
  }
  if (item.image_path) await cleanupStorageObject(admin.storage.from("cms-images"), "cms-images", item.image_path, "replace");
}

async function saveWithImage(kind: CmsKind, formData: FormData) {
  const schema = kind === "page" ? cmsPageSchema : kind === "news" ? cmsNewsSchema : cmsEventSchema;
  const parsed = schema.safeParse(formValues(formData));
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid content");
  try {
    const { supabase, item } = await saveDraft(tableFor[kind], parsed.data);
    await syncDraftImage(tableFor[kind], kind, formData, item, supabase);
  } catch (error) {
    if (error instanceof Error) fail(error.message);
    throw error;
  }
}

export async function saveCmsPage(formData: FormData) { await saveWithImage("page", formData); paths(); redirect("/admin/cms?notice=Page+draft+saved" as never); }
export async function saveCmsNews(formData: FormData) { await saveWithImage("news", formData); paths(); redirect("/admin/cms?notice=News+draft+saved" as never); }
export async function saveCmsEvent(formData: FormData) { await saveWithImage("event", formData); paths(); redirect("/admin/cms?notice=Event+draft+saved" as never); }

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
  const { data: item, error: readError } = await supabase.from(table).select("image_path").eq("id", parsed.data.id).eq("status", "draft").maybeSingle();
  if (readError || !item) fail("Only your own draft can be deleted.");
  const { error, count } = await supabase.from(table).delete({ count: "exact" }).eq("id", parsed.data.id).eq("status", "draft");
  if (error || count !== 1) fail(error?.message ?? "Only your own draft can be deleted.");
  if (item.image_path) await cleanupStorageObject(createAdminClient().storage.from("cms-images"), "cms-images", item.image_path, "remove");
  paths(); redirect("/admin/cms?notice=Draft+deleted" as never);
}
