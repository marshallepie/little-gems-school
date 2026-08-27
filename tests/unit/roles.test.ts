import { describe, expect, it } from "vitest";
import { roleCodeSchema } from "../../lib/validations/roles";

describe("roleCodeSchema", () => {
  it("accepts only the four foundation roles", () => {
    expect(roleCodeSchema.safeParse("parent").success).toBe(true);
    expect(roleCodeSchema.safeParse("principal").success).toBe(false);
  });
});
