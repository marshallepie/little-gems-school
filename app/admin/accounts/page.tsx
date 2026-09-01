import { AccountManager } from "@/components/account-manager";
import { requireProprietor } from "@/lib/auth/require-role";
import { createAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

export default async function AccountLifecyclePage() {
  await requireProprietor();
  const admin = createAdminClient();
  const { data: users, error: usersError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (usersError) throw new Error("Unable to load accounts.");
  const ids = users.users.map((user) => user.id);
  const [{ data: profiles, error: profilesError }, { data: positions, error: positionsError }, { data: authorizationEvents, error: eventsError }] = await Promise.all([
    ids.length ? admin.from("profiles").select("id, default_role_code, is_active, auth_ban_state").in("id", ids) : Promise.resolve({ data: [], error: null }),
    ids.length ? admin.from("admin_position_assignments").select("user_id, position_code, revoked_at").in("user_id", ids).is("revoked_at", null) : Promise.resolve({ data: [], error: null }),
    admin.from("authorization_events").select("id, occurred_at, actor_user_id, subject_user_id, event_type, position_code, role_code").order("occurred_at", { ascending: false }).limit(100),
  ]);
  if (profilesError || positionsError || eventsError) throw new Error("Unable to load authorization details.");
  const profileById = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
  const positionByUserId = new Map((positions ?? []).map((position) => [position.user_id, position.position_code]));
  const emailById = new Map(users.users.map((user) => [user.id, user.email ?? "No email"]));
  const accounts = users.users.map((user) => {
    const profile = profileById.get(user.id);
    const position = positionByUserId.get(user.id) ?? null;
    return { id: user.id, email: user.email ?? "No email", role: profile?.default_role_code ?? null, position, active: profile?.is_active === true, authBanState: profile?.auth_ban_state ?? null, isProprietor: position === "proprietor_super_admin" };
  }).sort((a, b) => a.email.localeCompare(b.email));
  const events = (authorizationEvents ?? []).map((event) => ({
    id: event.id,
    occurredAt: event.occurred_at,
    actor: event.actor_user_id ? emailById.get(event.actor_user_id) ?? event.actor_user_id : "System",
    subject: event.subject_user_id ? emailById.get(event.subject_user_id) ?? event.subject_user_id : "—",
    eventType: event.event_type,
    position: event.position_code,
    role: event.role_code,
  }));

  return <main className="mx-auto max-w-6xl space-y-6"><header><p className="font-semibold text-violet-700">Little Gems School</p><h1 className="text-3xl font-bold">Account lifecycle and authorization</h1><p className="mt-2 max-w-3xl text-slate-700">Proprietor-only account provisioning, Tier 2/3 position management, and authorization audit review.</p></header><AccountManager accounts={accounts} events={events} /></main>;
}
