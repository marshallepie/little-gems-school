import { describe, expect, it } from "vitest";
import { roleCodeSchema } from "../../lib/validations/roles";

describe("roleCodeSchema", () => {
  it("accepts the supported portal roles including secretary", () => {
    expect(roleCodeSchema.safeParse("parent").success).toBe(true);
    expect(roleCodeSchema.safeParse("secretary").success).toBe(true);
    expect(roleCodeSchema.safeParse("principal").success).toBe(false);
  });
});
