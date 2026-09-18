import { describe, expect, it } from "vitest";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
const root = resolve(import.meta.dirname, "../..");
const signup = readFileSync(resolve(root, "components/signup-form.tsx"), "utf8");
const login = readFileSync(resolve(root, "app/(auth)/login/page.tsx"), "utf8");
const controls = readFileSync(resolve(root, "components/portal-account-controls.tsx"), "utf8");
const migration = readFileSync(resolve(root, "supabase/migrations/20260912000000_account_hierarchy_public_signup_disposable_purge.sql"), "utf8");
const purgeHardening = readFileSync(resolve(root, "supabase/migrations/20260912010000_harden_disposable_account_purge.sql"), "utf8");
describe("public signup and account hierarchy source boundaries", () => {
  it("uses browser signUp with password confirmation and no role/profile mutation", () => {
    expect(signup).toContain("auth.signUp({ email, password"); expect(signup).toContain("emailRedirectTo: confirmationRedirect()"); expect(signup).toContain("password !== confirmation");
    expect(signup).not.toMatch(/service_role|createAdminClient|profiles\)|user_roles|admin_position/);
  });
  it("keeps navigation to home on login and portal logout surfaces", () => { expect(login).toContain('href="/"'); expect(controls).toContain('href="/"'); expect(controls).toContain('router.replace("/login")'); });
  it("encodes the actor matrix and makes privileged capabilities service-only", () => {
    expect(migration).toContain("target_position_code = 'headmistress'"); expect(migration).toContain("target_role_code in ('teacher', 'parent', 'student', 'secretary')");
    expect(migration).toContain("perform app_private.require_service_role()"); expect(migration).toContain("revoke all on function public.provision_portal_account_from_server");
    expect(migration).toContain("explicit disposable classification is required"); expect(migration).toContain("linked historical or person records require operator review");
    expect(purgeHardening).toContain("disposable_account_purge_retry_started");
    expect(purgeHardening).toContain("disposable_account_purge_auth_verification_failed");
    for (const table of ["timetable_entries", "attendance_sessions", "attendance_records", "assignments", "assessments", "assessment_results", "announcements", "events", "documents", "operational_events", "cms_pages", "cms_news_posts", "public_events"]) expect(purgeHardening).toContain(`public.${table}`);
  });
});
