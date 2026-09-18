import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { roleCodeSchema, type RoleCode } from "@/lib/validations/roles";

export type AdminPermission =
  | "school_records.read" | "people.manage" | "academic_structure.manage" | "enrolments.manage" | "teacher_assignments.manage"
  | "authorization.manage" | "timetable.manage" | "attendance.review" | "assessments.review" | "results.release"
  | "communications.manage" | "calendar.manage" | "documents.manage" | "website.manage" | "website_content.edit" | "website_content.publish";
type AuthenticatedClient = Awaited<ReturnType<typeof createClient>>;

async function requireCompletedProfile(supabase: AuthenticatedClient, userId: string) {
  const { data: profile, error } = await supabase.from("profiles").select("profile_completed_at, is_active").eq("id", userId).maybeSingle();
  if (error || !profile?.is_active) redirect("/login");
  if (!profile.profile_completed_at) redirect("/profile");
}

/** Token validation plus a fail-closed active-account check for server actions. */
export async function requireActiveProfileSession() {
  const supabase = await createClient();
  const { data: claimResult } = await supabase.auth.getClaims();
  const userId = claimResult?.claims.sub;
  if (!userId) redirect("/login");
  const { data: profile, error } = await supabase.from("profiles").select("is_active").eq("id", userId).maybeSingle();
  if (error || !profile?.is_active) redirect("/login");
  return { supabase, userId };
}
async function requireAuthenticatedClient() { const { supabase, userId } = await requireActiveProfileSession(); await requireCompletedProfile(supabase, userId); return { supabase, userId }; }

export async function requireRole(): Promise<RoleCode> {
  const { supabase, userId } = await requireAuthenticatedClient();
  const { data, error } = await supabase.from("profiles").select("default_role_code, is_active").eq("id", userId).maybeSingle();
  if (error || !data?.is_active || !data.default_role_code) redirect("/login");
  const role = roleCodeSchema.safeParse(data.default_role_code);
  if (!role.success) redirect("/login");
  const { data: assigned } = await supabase.from("user_roles").select("roles!inner(code)").eq("user_id", userId);
  const isAssigned = assigned?.some((entry) => { const embedded = entry.roles as unknown as { code: string } | { code: string }[] | null; return (Array.isArray(embedded) ? embedded : embedded ? [embedded] : []).some((assignedRole) => assignedRole.code === role.data); });
  if (!isAssigned) redirect("/login");
  return role.data;
}
export async function requireAdminPermission(permission: AdminPermission) { const { supabase } = await requireAuthenticatedClient(); const { data: allowed, error } = await supabase.rpc("has_admin_permission", { required_permission: permission }); if (error || allowed !== true) redirect("/unauthorized"); return supabase; }
export async function requireWebsiteContentEditor() { const { supabase } = await requireAuthenticatedClient(); const { data: allowed, error } = await supabase.rpc("has_website_content_edit_permission"); if (error || allowed !== true) redirect("/unauthorized"); return supabase; }
export async function requireProprietor() { const { supabase } = await requireAuthenticatedClient(); const { data: allowed, error } = await supabase.rpc("is_proprietor"); if (error || allowed !== true) redirect("/unauthorized"); return supabase; }
export async function requireProprietorSession() { const { supabase, userId } = await requireAuthenticatedClient(); const { data: allowed, error } = await supabase.rpc("is_proprietor"); if (error || allowed !== true) redirect("/unauthorized"); return { supabase, userId }; }

export type AccountManagementCapabilities = { manage_accounts: boolean; can_purge_disposable: boolean; position: "proprietor_super_admin" | "senior_administrator" | "headmistress" | null };
/** Cookie-session gate for account actions; FormData never selects the actor tier. */
export async function requireAccountManagementSession() {
  const { supabase, userId } = await requireAuthenticatedClient();
  const { data, error } = await supabase.rpc("account_management_capabilities");
  const capabilities = data as AccountManagementCapabilities | null;
  if (error || !capabilities?.manage_accounts) redirect("/unauthorized");
  return { supabase, userId, capabilities };
}
