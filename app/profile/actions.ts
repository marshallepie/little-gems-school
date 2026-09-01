"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const optionalText = (maximum: number) => z.string().trim().max(maximum).transform((value) => value || null);
const profileSchema = z.object({
  display_name: z.string().trim().min(1, "Full name is required.").max(120),
  phone: optionalText(40),
  address: optionalText(500),
  avatar_url: z.union([z.literal(""), z.string().trim().url().refine((url) => url.startsWith("https://"), "Avatar URL must use HTTPS.")]).transform((value) => value || null),
});

export async function updateMyProfile(formData: FormData) {
  const parsed = profileSchema.safeParse({
    display_name: formData.get("display_name"), phone: formData.get("phone"),
    address: formData.get("address"), avatar_url: formData.get("avatar_url"),
  });
  if (!parsed.success) redirect(`/profile?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid profile.")}` as never);

  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims.sub) redirect("/login");
  const { error } = await supabase.from("profiles").update({ ...parsed.data, profile_completed_at: new Date().toISOString() }).eq("id", claims.claims.sub);
  if (error) redirect(`/profile?error=${encodeURIComponent(error.message)}` as never);
  revalidatePath("/profile");
  redirect("/dashboard");
}
