import { afterEach, describe, expect, it, vi } from "vitest";
import { cleanupStorageObject } from "../../lib/storage-cleanup";

describe("storage cleanup", () => {
  afterEach(() => vi.restoreAllMocks());

  it("logs a path-free structured failure and leaves successful metadata work intact", async () => {
    const remove = vi.fn().mockResolvedValue({ error: { message: "failed for secret/object.png", statusCode: 500 } });
    const error = vi.spyOn(console, "error").mockImplementation(() => undefined);
    await expect(cleanupStorageObject({ remove }, "cms-images", "content/page/secret/object.png", "replace")).resolves.toBe(false);
    expect(remove).toHaveBeenCalledWith(["content/page/secret/object.png"]);
    expect(error).toHaveBeenCalledWith("storage_cleanup_failed", {
      bucket: "cms-images", operation: "replace", statusCode: 500, errorType: "provider_error",
    });
    expect(JSON.stringify(error.mock.calls)).not.toContain("secret/object.png");
  });
});
