import { describe, expect, it } from "vitest";
import { readFileSync, readdirSync } from "node:fs";
import { resolve } from "node:path";

const source = (file: string) => readFileSync(resolve(process.cwd(), file), "utf8");

const roleRouteDirectories = [
  ["app/admin", "admin"],
  ["app/teacher", "teacher"],
  ["app/parent", "parent"],
  ["app/student", "student"],
] as const;

describe("portal usability and account access", () => {
  it("uses an explicit role for navigation rather than deriving it from display copy", () => {
    const dashboardUi = source("components/dashboard-ui.tsx");
    expect(dashboardUi).toContain("function portalConfig(role: PortalRole)");
    expect(dashboardUi).not.toContain("portalConfig(eyebrow)");
    expect(dashboardUi).toContain('case "admin"');
    expect(dashboardUi).toContain('href={config.homeHref}');
    expect(dashboardUi).toContain("Back to");
    expect(dashboardUi).toContain("Need help?");
  });

  it("assigns administrator navigation to Operations and Admissions regardless of their eyebrow", () => {
    for (const file of [
      "app/admin/admissions/page.tsx",
      "app/admin/operations/assessments/page.tsx",
      "app/admin/operations/assignments/page.tsx",
      "app/admin/operations/attendance/page.tsx",
      "app/admin/operations/timetable/page.tsx",
    ]) {
      const page = source(file);
      expect(page).toContain('<PortalHeader role="admin"');
    }
  });

  it("provides reusable portal navigation on account lifecycle and CMS pages", () => {
    for (const file of ["app/admin/accounts/page.tsx", "app/admin/cms/page.tsx"]) {
      const page = source(file);
      expect(page).toContain('import { PortalHeader } from "@/components/dashboard-ui";');
      expect(page).toContain('<PortalHeader role="admin"');
      expect(page).toContain("</PortalHeader>");
    }
  });

  it("gives every authenticated role route an explicit matching navigation role", () => {
    for (const [directory, role] of roleRouteDirectories) {
      const routeFiles = readdirSync(resolve(process.cwd(), directory), { recursive: true })
        .filter((entry): entry is string => typeof entry === "string" && entry.endsWith("page.tsx"));
      for (const relativePath of routeFiles) {
        const page = source(`${directory}/${relativePath}`);
        expect(page).toContain(`<PortalHeader role="${role}"`);
      }
    }
    expect(source("app/profile/page.tsx")).toContain('<PortalHeader role="profile"');
  });

  it("keeps password updates behind a Supabase user check, confirmation, and native constraints", () => {
    const authForm = source("components/auth-form.tsx");
    expect(authForm).toContain('href="/forgot-password"');
    expect(authForm).toContain("passwordConfirmation");
    expect(authForm).toContain("password !== passwordConfirmation");
    expect(authForm).toContain("supabase.auth.getUser()");
    expect(authForm).toContain("Show password");
    expect(authForm).not.toContain("noValidate");
    expect(authForm).toContain("required minLength={8}");
  });

  it("exposes the signed-in security path", () => {
    const profile = source("app/profile/page.tsx");
    expect(profile).toContain("Security");
    expect(profile).toContain('href="/update-password"');
  });
});
