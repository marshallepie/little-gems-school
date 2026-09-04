import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { roleCodeSchema, type RoleCode } from "@/lib/validations/roles";

export type AdminPermission =
  | "school_records.read"
  | "people.manage"
  | "academic_structure.manage"
  | "enrolments.manage"
  | "teacher_assignments.manage"
  | "authorization.manage"
  | "timetable.manage"
  | "attendance.review"
  | "assessments.review"
  | "results.release"
  | "communications.manage"
  | "calendar.manage"
  | "documents.manage"
  | "website.manage";

type AuthenticatedClient = Awaited<ReturnType<typeof createClient>>;

/** Central completion gate for every authenticated portal route and server action. */
async function requireCompletedProfile(supabase: AuthenticatedClient, userId: string) {
  const { data: profile, error } = await supabase
    .from("profiles")
    .select("profile_completed_at, is_active")
    .eq("id", userId)
    .maybeSingle();
  if (error || !profile?.is_active) redirect("/login");
  // `/profile` itself uses createClient directly, so this redirect cannot loop.
  if (!profile.profile_completed_at) redirect("/profile");
}

async function requireAuthenticatedClient() {
  const supabase = await createClient();
  // getClaims() validates the token; getSession() is intentionally not used to authorize.
  const { data: claimResult } = await supabase.auth.getClaims();
  const userId = claimResult?.claims.sub;
  if (!userId) redirect("/login");
  await requireCompletedProfile(supabase, userId);
  return { supabase, userId };
}

export async function requireRole(): Promise<RoleCode> {
  const { supabase, userId } = await requireAuthenticatedClient();
  const { data, error } = await supabase.from("profiles").select("default_role_code, is_active").eq("id", userId).maybeSingle();
  if (error || !data?.is_active || !data.default_role_code) redirect("/login");
  const role = roleCodeSchema.safeParse(data.default_role_code);
  if (!role.success) redirect("/login");
  const { data: assigned } = await supabase.from("user_roles").select("roles!inner(code)").eq("user_id", userId);
  const isAssigned = assigned?.some((entry) => {
    const embedded = entry.roles as unknown as { code: string } | { code: string }[] | null;
    const codes = Array.isArray(embedded) ? embedded : embedded ? [embedded] : [];
    return codes.some((assignedRole) => assignedRole.code === role.data);
  });
  if (!isAssigned) redirect("/login");
  return role.data;
}

/** Server-side guard; the RPC only returns a boolean backed by RLS-safe helpers. */
export async function requireAdminPermission(permission: AdminPermission) {
  const { supabase } = await requireAuthenticatedClient();
  const { data: allowed, error } = await supabase.rpc("has_admin_permission", { required_permission: permission });
  if (error || allowed !== true) redirect("/unauthorized");
  return supabase;
}

/** Exact active proprietor check using the normal cookie-bound user session. */
export async function requireProprietor() {
  const { supabase } = await requireAuthenticatedClient();
  const { data: allowed, error } = await supabase.rpc("is_proprietor");
  if (error || allowed !== true) redirect("/unauthorized");
  return supabase;
}

/** Use before invoking a service-role-only capability so the actor is auditable. */
export async function requireProprietorSession() {
  const { supabase, userId } = await requireAuthenticatedClient();
  const { data: allowed, error } = await supabase.rpc("is_proprietor");
  if (error || allowed !== true) redirect("/unauthorized");
  return { supabase, userId };
}
