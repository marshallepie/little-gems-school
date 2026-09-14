"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { requireActiveProfileSession } from "../../lib/auth/require-role";
import { imagePath, validateImageUpload } from "../../lib/image-upload";
import { cleanupStorageObject } from "../../lib/storage-cleanup";
import { createAdminClient } from "../../lib/supabase/admin";

const optionalText = (maximum: number) => z.string().trim().max(maximum).transform((value) => value || null);
const profileSchema = z.object({
  display_name: z.string().trim().min(1, "Full name is required.").max(120),
  phone: optionalText(40),
  address: optionalText(500),
});
function fail(message: string): never { redirect(`/profile?error=${encodeURIComponent(message)}` as never); }

export async function updateMyProfile(formData: FormData) {
  const parsed = profileSchema.safeParse({ display_name: formData.get("display_name"), phone: formData.get("phone"), address: formData.get("address") });
  if (!parsed.success) fail(parsed.error.issues[0]?.message ?? "Invalid profile.");
  let avatar: File | null;
  try { avatar = await validateImageUpload(formData.get("avatar")); } catch (error) { fail(error instanceof Error ? error.message : "Invalid avatar image."); }
  const { supabase, userId } = await requireActiveProfileSession();
  const { data: profile, error: profileError } = await supabase.from("profiles").select("avatar_path").eq("id", userId).maybeSingle();
  if (profileError || !profile) fail("Unable to load your profile.");
  let avatarPath = profile.avatar_path as string | null;
  if (avatar) {
    const admin = createAdminClient();
    const nextPath = imagePath("avatar", userId, avatar.type as "image/jpeg" | "image/png" | "image/webp");
    const { error: uploadError } = await admin.storage.from("profile-avatars").upload(nextPath, avatar, { contentType: avatar.type, upsert: false });
    if (uploadError) fail("Avatar upload failed. Please try again.");
    const { error: updateError } = await admin.from("profiles").update({ avatar_path: nextPath }).eq("id", userId);
    if (updateError) { await cleanupStorageObject(admin.storage.from("profile-avatars"), "profile-avatars", nextPath, "rollback"); fail("Unable to save your avatar."); }
    if (avatarPath) await cleanupStorageObject(admin.storage.from("profile-avatars"), "profile-avatars", avatarPath, "replace");
    avatarPath = nextPath;
  }
  if (formData.get("remove_avatar") === "on" && !avatar && avatarPath) {
    const admin = createAdminClient();
    const { error } = await admin.from("profiles").update({ avatar_path: null }).eq("id", userId);
    if (error) fail("Unable to remove your avatar.");
    await cleanupStorageObject(admin.storage.from("profile-avatars"), "profile-avatars", avatarPath, "remove");
  }
  const { error } = await supabase.from("profiles").update({ ...parsed.data, profile_completed_at: new Date().toISOString() }).eq("id", userId);
  if (error) fail(error.message);
  revalidatePath("/profile");
  redirect("/dashboard");
}
