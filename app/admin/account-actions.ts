"use server";

import { randomBytes } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireProprietorSession } from "@/lib/auth/require-role";
import { createAdminClient } from "@/lib/supabase/admin";
import { completePendingAuthBan } from "@/lib/account-lifecycle";

const roleSchema = z.enum(["admin", "teacher", "parent", "student"]);
const positionSchema = z.enum(["senior_administrator", "headmistress"]);
const createAccountSchema = z.object({
  email: z.string().trim().email().max(254),
  role: roleSchema,
  position: positionSchema.optional(),
}).superRefine(({ role, position }, ctx) => {
  if (role === "admin" && !position) ctx.addIssue({ code: "custom", path: ["position"], message: "Choose an administrator position." });
  if (role !== "admin" && position) ctx.addIssue({ code: "custom", path: ["position"], message: "Only administrator accounts can receive an administrator position." });
});
const deprovisionSchema = z.object({ userId: z.string().uuid() });
const positionChangeSchema = z.object({ userId: z.string().uuid(), position: z.union([positionSchema, z.literal("")]) });

export type AccountActionState = { error?: string; temporaryPassword?: string; email?: string };
const initialError = (message: string): AccountActionState => ({ error: message });

function temporaryPassword() {
  // 32 random bytes plus every required character class; never log or persist it.
  return `${randomBytes(32).toString("base64url")}aA1!`;
}

export async function createAccount(_previous: AccountActionState, formData: FormData): Promise<AccountActionState> {
  const parsed = createAccountSchema.safeParse({
    email: formData.get("email"), role: formData.get("role"), position: formData.get("position") || undefined,
  });
  if (!parsed.success) return initialError(parsed.error.issues[0]?.message ?? "Invalid account details.");

  const proprietor = await requireProprietorSession();
  const password = temporaryPassword();
  const admin = createAdminClient();
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: parsed.data.email, password, email_confirm: true,
  });
  if (createError || !created.user) return initialError(createError?.message ?? "Unable to create account.");

  const { error: provisionError } = await proprietor.supabase.rpc("provision_portal_account", {
    target_user_id: created.user.id, target_role_code: parsed.data.role, target_position_code: parsed.data.position ?? null,
  });
  if (provisionError) {
    const { error: rollbackError } = await admin.auth.admin.deleteUser(created.user.id);
    return initialError(rollbackError ? "Account provisioning failed and requires operator review." : provisionError.message);
  }

  revalidatePath("/admin/accounts");
  return { temporaryPassword: password, email: parsed.data.email };
}

async function completeAuthBan(userId: string) {
  // First authenticate/authorize the browser session as proprietor. Only then use
  // the server-only service client to persist the external Auth-ban outcome.
  const proprietor = await requireProprietorSession();
  const admin = createAdminClient();
  const result = await completePendingAuthBan({
    banAuthUser: async () => admin.auth.admin.updateUserById(userId, { ban_duration: "876000h" }),
    markFailure: async () => admin.rpc("record_account_auth_ban_state_from_server", { target_user_id: userId, actor_user_id: proprietor.userId, outcome: "failed" }),
    markCompleted: async () => admin.rpc("record_account_auth_ban_state_from_server", { target_user_id: userId, actor_user_id: proprietor.userId, outcome: "succeeded" }),
  });
  revalidatePath("/admin/accounts");
  if (!result.completed) throw new Error(result.error);
}

export async function deprovisionAccount(formData: FormData): Promise<void> {
  const parsed = deprovisionSchema.safeParse({ userId: formData.get("userId") });
  if (!parsed.success) throw new Error("Invalid account.");
  const proprietor = await requireProprietorSession();
  const { error: deprovisionError } = await proprietor.supabase.rpc("deprovision_portal_account", { target_user_id: parsed.data.userId });
  if (deprovisionError) throw new Error(deprovisionError.message);
  await completeAuthBan(parsed.data.userId);
}

export async function retryPendingAuthBan(formData: FormData): Promise<void> {
  const parsed = deprovisionSchema.safeParse({ userId: formData.get("userId") });
  if (!parsed.success) throw new Error("Invalid account.");
  await completeAuthBan(parsed.data.userId);
}

/** Assign, replace, or revoke only Tier 2/3 positions through the service-only RPC. */
export async function changeAdministratorPosition(formData: FormData): Promise<void> {
  const parsed = positionChangeSchema.safeParse({ userId: formData.get("userId"), position: formData.get("position") });
  if (!parsed.success) throw new Error("Invalid administrator position change.");
  const proprietor = await requireProprietorSession();
  const { error } = await createAdminClient().rpc("set_admin_position_from_server", {
    target_user_id: parsed.data.userId,
    actor_user_id: proprietor.userId,
    target_position_code: parsed.data.position || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/accounts");
}
