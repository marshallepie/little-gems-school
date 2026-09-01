import { readFile } from "node:fs/promises";
import { describe, expect, it } from "vitest";
// @ts-expect-error -- The security-sensitive operator script is plain ESM, not app TypeScript.
import { assertZeroAuthUsers } from "../../scripts/bootstrap-initial-production-auth.mjs";

function adminListing(data: unknown, error: { message: string } | null = null) {
  const listUsers = async () => ({ data, error });
  return { auth: { admin: { listUsers } } };
}

describe("initial production Auth bootstrap guard", () => {
  it("accepts only an unambiguous zero-user pagination result", async () => {
    const admin = adminListing({ users: [], total: 0, lastPage: 0, nextPage: null });

    await expect(assertZeroAuthUsers(admin, "during test")).resolves.toBeUndefined();
  });

  it("rejects users and incomplete pagination metadata", async () => {
    await expect(assertZeroAuthUsers(
      adminListing({ users: [], total: 1, lastPage: 1, nextPage: null }),
      "during test",
    )).rejects.toThrow("Refusing to run");
    await expect(assertZeroAuthUsers(
      adminListing({ users: [], total: 0 }),
      "during test",
    )).rejects.toThrow("Auth user listing is uncertain");
    await expect(assertZeroAuthUsers(
      adminListing({ users: [], total: 0, lastPage: 1, nextPage: null }),
      "during test",
    )).rejects.toThrow("Auth user listing is uncertain");
  });

  it("performs the final guard after prompts and before createUser", async () => {
    const source = await readFile(
      new URL("../../scripts/bootstrap-initial-production-auth.mjs", import.meta.url),
      "utf8",
    );
    const guards = [...source.matchAll(/await assertZeroAuthUsers\(admin, '([^']+)'\);/g)];

    expect(guards.map((match) => match[1])).toEqual([
      "during initial preflight",
      "immediately before Auth creation",
    ]);
    expect(guards[1].index).toBeLessThan(source.indexOf("admin.auth.admin.createUser"));
  });
});
