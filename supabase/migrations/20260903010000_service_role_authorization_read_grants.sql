-- Allow service_role to read required authorization columns.
grant select (id, default_role_code, is_active, auth_ban_state, auth_ban_last_failed_at, auth_ban_completed_at) on table public.profiles to service_role;
grant select (user_id) on table public.user_roles to service_role;
grant select (user_id, position_code, revoked_at) on table public.admin_position_assignments to service_role;
grant select (id, occurred_at, actor_user_id, subject_user_id, event_type, position_code, role_code, metadata) on table public.authorization_events to service_role;
