"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { requireActiveProfileSession } from "@/lib/auth/require-role";
import { announcementSchema, eventSchema, parseAudiences, parseUtcDateTime } from "@/lib/validations/communications";

function fail(path: string, message: string): never { redirect(`${path}?error=${encodeURIComponent(message)}` as never); }
function values(formData: FormData) { return { ...Object.fromEntries(formData.entries()), audiences: formData.getAll("audiences").map(String) }; }
function revalidateFeeds() {
  for (const path of ["/admin/communications", "/admin/calendar", "/teacher", "/teacher/communications", "/teacher/calendar", "/parent", "/parent/communications", "/parent/calendar", "/student", "/student/communications", "/student/calendar"]) revalidatePath(path);
}

/** Cookie-bound session only; each mutation is one database command RPC. */
export async function saveAnnouncement(formData: FormData) {
  const parsed = announcementSchema.safeParse(values(formData));
  if (!parsed.success) fail("/admin/communications", parsed.error.issues[0]?.message ?? "Invalid announcement");
  const audiences = parseAudiences(parsed.data.audiences);
  if (!audiences) fail("/admin/communications", "Choose each audience only once using an approved option");
  const { supabase } = await requireActiveProfileSession();
  const { error } = await supabase.rpc("manage_internal_announcement", {
    p_id: parsed.data.id || null,
    p_action: parsed.data.intent,
    p_title: parsed.data.title,
    p_body: parsed.data.body,
    p_targets: audiences,
  });
  if (error) fail("/admin/communications", error.message);
  revalidateFeeds();
  redirect(`/admin/communications?notice=Announcement+${parsed.data.intent === "publish" ? "published" : parsed.data.intent === "archive" ? "archived" : "saved"}` as never);
}

export async function saveEvent(formData: FormData) {
  const parsed = eventSchema.safeParse(values(formData));
  if (!parsed.success) fail("/admin/calendar", parsed.error.issues[0]?.message ?? "Invalid event");
  const audiences = parseAudiences(parsed.data.audiences);
  const startsAt = parseUtcDateTime(parsed.data.starts_at);
  const endsAt = parseUtcDateTime(parsed.data.ends_at);
  if (!audiences) fail("/admin/calendar", "Choose each audience only once using an approved option");
  if (!startsAt || !endsAt) fail("/admin/calendar", "Choose a real UTC date and time");
  const { supabase } = await requireActiveProfileSession();
  const { error } = await supabase.rpc("manage_private_event", {
    p_id: parsed.data.id || null,
    p_action: parsed.data.intent,
    p_title: parsed.data.title,
    p_description: parsed.data.description,
    p_starts_at: startsAt,
    p_ends_at: endsAt,
    p_targets: audiences,
  });
  if (error) fail("/admin/calendar", error.message);
  revalidateFeeds();
  redirect(`/admin/calendar?notice=Event+${parsed.data.intent === "publish" ? "published" : parsed.data.intent === "cancel" ? "cancelled" : "saved"}` as never);
}
