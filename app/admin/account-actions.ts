"use server";

import { randomBytes } from "node:crypto";
import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireAccountManagementSession, requireProprietorSession } from "@/lib/auth/require-role";
import { createAdminClient } from "@/lib/supabase/admin";
import { completePendingAuthBan, completeReprovisionSaga, type ReprovisionLifecycleState } from "@/lib/account-lifecycle";

const roleSchema = z.enum(["admin", "teacher", "parent", "student", "secretary"]);
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
const reprovisionSchema = z.object({
  userId: z.string().uuid(),
  role: roleSchema,
  position: positionSchema.optional(),
}).superRefine(({ role, position }, ctx) => {
  if (role === "admin" && !position) ctx.addIssue({ code: "custom", path: ["position"], message: "Choose an administrator position." });
  if (role !== "admin" && position) ctx.addIssue({ code: "custom", path: ["position"], message: "Only administrator accounts can receive an administrator position." });
});
const positionChangeSchema = z.object({ userId: z.string().uuid(), position: z.union([positionSchema, z.literal("")]) });
const websiteEditorSchema = z.object({ userId: z.string().uuid(), enabled: z.enum(["true", "false"]) });

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

  const actor = await requireAccountManagementSession();
  const password = temporaryPassword();
  const admin = createAdminClient();
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email: parsed.data.email, password, email_confirm: true,
  });
  if (createError || !created.user) return initialError(createError?.message ?? "Unable to create account.");

  const { error: provisionError } = await admin.rpc("provision_portal_account_from_server", {
    target_user_id: created.user.id, actor_user_id: actor.userId, target_role_code: parsed.data.role, target_position_code: parsed.data.position ?? null,
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

/**
 * Re-provision only after the Auth-ban saga is durably complete. Auth is reset and
 * unbanned before the database activation RPC; an RPC failure is compensated by
 * re-banning only when a fresh read confirms the profile is still inactive.
 */
export async function reprovisionAccount(_previous: AccountActionState, formData: FormData): Promise<AccountActionState> {
  const parsed = reprovisionSchema.safeParse({
    userId: formData.get("userId"), role: formData.get("role"), position: formData.get("position") || undefined,
  });
  if (!parsed.success) return initialError(parsed.error.issues[0]?.message ?? "Invalid re-provisioning details.");

  const proprietor = await requireProprietorSession();
  const admin = createAdminClient();
  const { data: profile, error: profileError } = await admin
    .from("profiles")
    .select("is_active, auth_ban_state")
    .eq("id", parsed.data.userId)
    .maybeSingle();
  if (profileError || !profile || profile.is_active || profile.auth_ban_state !== "succeeded") {
    return initialError("Only a fully deprovisioned account can be re-provisioned.");
  }

  const password = temporaryPassword();
  const result = await completeReprovisionSaga({
    resetPasswordAndUnban: async () => admin.auth.admin.updateUserById(parsed.data.userId, { password, ban_duration: "none" }),
    activateDatabase: async () => admin.rpc("reprovision_portal_account_from_server", {
      target_user_id: parsed.data.userId,
      actor_user_id: proprietor.userId,
      target_role_code: parsed.data.role,
      target_position_code: parsed.data.position ?? null,
    }),
    readLifecycleState: async (): Promise<ReprovisionLifecycleState> => {
      const { data: currentProfile, error } = await admin.from("profiles").select("is_active").eq("id", parsed.data.userId).maybeSingle();
      if (error || !currentProfile) return "unknown";
      return currentProfile.is_active ? "active" : "inactive";
    },
    rebanAuthUser: async () => admin.auth.admin.updateUserById(parsed.data.userId, { ban_duration: "876000h" }),
    // This server-only, append-only event documents an indeterminate result without
    // recording the temporary password or any other secret.
    recordReconciliationNeeded: async () => admin.rpc("record_account_reprovision_reconciliation_needed_from_server", {
      target_user_id: parsed.data.userId,
      actor_user_id: proprietor.userId,
    }),
  });
  if (!result.completed) return initialError(result.error);

  revalidatePath("/admin/accounts");
  return { temporaryPassword: password, email: "the re-provisioned account" };
}

export async function changeWebsiteContentEditor(formData: FormData): Promise<void> {
  const parsed = websiteEditorSchema.safeParse({ userId: formData.get("userId"), enabled: formData.get("enabled") });
  if (!parsed.success) throw new Error("Invalid website editor change.");
  const proprietor = await requireProprietorSession();
  const { error } = await createAdminClient().rpc("set_website_content_editor_from_server", {
    target_user_id: parsed.data.userId, actor_user_id: proprietor.userId, enabled: parsed.data.enabled === "true",
  });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/accounts");
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


const disposableSchema = z.object({ userId: z.string().uuid(), confirmation: z.literal("PURGE DISPOSABLE") });

function isConfirmedAuthUserNotFound(error: unknown): boolean {
  if (!error || typeof error !== "object") return false;
  return "status" in error && error.status === 404;
}

/** Explicit classification is separate from destructive purge and proprietor-only. */
export async function classifyDisposableTestAccount(formData: FormData): Promise<void> {
  const parsed = disposableSchema.safeParse({ userId: formData.get("userId"), confirmation: formData.get("confirmation") });
  if (!parsed.success) throw new Error("Type PURGE DISPOSABLE to classify a disposable test account.");
  const proprietor = await requireProprietorSession();
  const { error } = await createAdminClient().rpc("classify_disposable_test_account_from_server", { target_user_id: parsed.data.userId, actor_user_id: proprietor.userId });
  if (error) throw new Error(error.message);
  revalidatePath("/admin/accounts");
}

/** Purge only explicitly classified, dependency-free disposable fixtures. */
export async function purgeDisposableTestAccount(formData: FormData): Promise<void> {
  const parsed = disposableSchema.safeParse({ userId: formData.get("userId"), confirmation: formData.get("confirmation") });
  if (!parsed.success) throw new Error("Type PURGE DISPOSABLE to confirm this destructive action.");
  const proprietor = await requireProprietorSession();
  const admin = createAdminClient();
  const { error: preflightError } = await admin.rpc("begin_disposable_account_purge_from_server", { target_user_id: parsed.data.userId, actor_user_id: proprietor.userId });
  if (preflightError) throw new Error(preflightError.message);
  const { error: deleteError } = await admin.auth.admin.deleteUser(parsed.data.userId);
  if (deleteError) {
    await admin.rpc("record_disposable_account_purge_auth_failed_from_server", { target_user_id: parsed.data.userId, actor_user_id: proprietor.userId });
    throw new Error("External Auth deletion failed; database access remains revoked and the disposable fixture requires a proprietor retry.");
  }
  const { data: readBack, error: readBackError } = await admin.auth.admin.getUserById(parsed.data.userId);
  // Only the Auth API's expected not-found response confirms deletion. A null
  // user with no error is indeterminate and must enter reconciliation.
  const confirmedAbsent = !readBack.user && isConfirmedAuthUserNotFound(readBackError);
  if (!confirmedAbsent) {
    const { error: reconciliationError } = await admin.rpc("record_disposable_account_purge_auth_verification_failed_from_server", {
      target_user_id: parsed.data.userId,
      actor_user_id: proprietor.userId,
    });
    if (reconciliationError) {
      throw new Error("Auth deletion could not be verified and the reconciliation audit could not be recorded; database access remains revoked for operator review.");
    }
    throw new Error(readBack.user
      ? "Auth deletion could not be verified; database access remains revoked for operator review."
      : "Auth deletion verification failed; database access remains revoked and the disposable fixture requires proprietor reconciliation.");
  }
  revalidatePath("/admin/accounts");
}
