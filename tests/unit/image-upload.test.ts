import { describe, expect, it } from "vitest";
import { MAX_IMAGE_BYTES, imagePath, validateImageUpload } from "../../lib/image-upload";

function image(type: string, bytes: number[]) { return new File([new Uint8Array(bytes)], "image.bin", { type }); }
describe("image upload validation", () => {
  it("allows only size-bounded images whose file signatures match their MIME type", async () => {
    await expect(validateImageUpload(image("image/png", [137, 80, 78, 71, 13, 10, 26, 10]))).resolves.toBeInstanceOf(File);
    await expect(validateImageUpload(image("image/jpeg", [137, 80, 78, 71, 13, 10, 26, 10]))).rejects.toThrow("does not match");
    await expect(validateImageUpload(image("image/gif", [71, 73, 70]))).rejects.toThrow("Choose a JPEG");
    expect(MAX_IMAGE_BYTES).toBe(5 * 1024 * 1024);
  });

  it("accepts canonical UUID-form owner IDs and generates UUID-v4 object IDs", () => {
    const ownerId = "b1000000-0000-0000-0000-000000000001";
    const v4ObjectId = "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
    expect(imagePath("avatar", ownerId, "image/png")).toMatch(new RegExp(`^avatars/${ownerId}/${v4ObjectId}\\.png$`));
    expect(imagePath("content", ownerId, "image/webp", "news")).toMatch(new RegExp(`^content/news/${ownerId}/${v4ObjectId}\\.webp$`));
    expect(() => imagePath("avatar", "not-a-uuid", "image/png")).toThrow("must be a UUID");
    expect(() => imagePath("content", ownerId, "image/png")).toThrow("kind is required");
  });
});
