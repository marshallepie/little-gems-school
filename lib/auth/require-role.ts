import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { roleCodeSchema, type RoleCode } from "@/lib/validations/roles";

export async function requireRole(): Promise<RoleCode> {
  const supabase = await createClient();
  // getClaims() validates the token; getSession() is intentionally not used to authorize.
  const { data: claimResult } = await supabase.auth.getClaims();
  const userId = claimResult?.claims.sub;
  if (!userId) redirect("/login");
  const { data, error } = await supabase.from("profiles").select("default_role_code").eq("id", userId).maybeSingle();
  if (error || !data?.default_role_code) redirect("/login");
  const role = roleCodeSchema.safeParse(data.default_role_code);
  if (!role.success) redirect("/login");
  const { data: assigned } = await supabase.from("user_roles").select("roles!inner(code)").eq("user_id", userId);
  const isAssigned = assigned?.some((entry) => entry.roles.some((assignedRole) => assignedRole.code === role.data));
  if (!isAssigned) redirect("/login");
  return role.data;
}
