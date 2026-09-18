import { AccountManager } from "@/components/account-manager";
import { PortalHeader } from "@/components/dashboard-ui";
import { requireProprietor } from "@/lib/auth/require-role";
import { createAdminClient } from "@/lib/supabase/admin";

export const dynamic = "force-dynamic";

export default async function AccountLifecyclePage() {
  await requireProprietor();
  const admin = createAdminClient();
  const { data: users, error: usersError } = await admin.auth.admin.listUsers({ page: 1, perPage: 1000 });
  if (usersError) throw new Error("Unable to load accounts.");
  const ids = users.users.map((user) => user.id);
  const [{ data: profiles, error: profilesError }, { data: positions, error: positionsError }, { data: editors, error: editorsError }, { data: authorizationEvents, error: eventsError }] = await Promise.all([
    ids.length ? admin.from("profiles").select("id, default_role_code, is_active, auth_ban_state").in("id", ids) : Promise.resolve({ data: [], error: null }),
    ids.length ? admin.from("admin_position_assignments").select("user_id, position_code, revoked_at").in("user_id", ids) : Promise.resolve({ data: [], error: null }),
    ids.length ? admin.from("website_content_editor_assignments").select("user_id").in("user_id", ids) : Promise.resolve({ data: [], error: null }),
    admin.from("authorization_events").select("id, occurred_at, actor_user_id, subject_user_id, event_type, position_code, role_code").order("occurred_at", { ascending: false }).limit(100),
  ]);
  if (profilesError || positionsError || editorsError || eventsError) throw new Error("Unable to load authorization details.");
  const profileById = new Map((profiles ?? []).map((profile) => [profile.id, profile]));
  const positionByUserId = new Map((positions ?? []).filter((position) => position.revoked_at === null).map((position) => [position.user_id, position.position_code]));
  const proprietorUserIds = new Set((positions ?? []).filter((position) => position.position_code === "proprietor_super_admin").map((position) => position.user_id));
  const emailById = new Map(users.users.map((user) => [user.id, user.email ?? "No email"]));
  const editorUserIds = new Set((editors ?? []).map((editor) => editor.user_id));
  const accounts = users.users.map((user) => {
    const profile = profileById.get(user.id);
    const position = positionByUserId.get(user.id) ?? null;
    return { id: user.id, email: user.email ?? "No email", role: profile?.default_role_code ?? null, position, active: profile?.is_active === true, authBanState: profile?.auth_ban_state ?? null, isProprietor: proprietorUserIds.has(user.id), websiteEditor: editorUserIds.has(user.id) };
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

  return <main className="mx-auto max-w-6xl space-y-6"><PortalHeader role="admin" eyebrow="Administrator" title="Account lifecycle and authorization"><p>Proprietor-only account provisioning, Tier 2/3 position management, and authorization audit review.</p></PortalHeader><AccountManager accounts={accounts} events={events} /></main>;
}
