import { randomUUID } from "crypto";

export const IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type ImageMimeType = (typeof IMAGE_MIME_TYPES)[number];
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

// Record IDs may be canonical UUID-form fixture/legacy values; generated object IDs are v4 below.
const OWNER_ID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const extensions: Record<ImageMimeType, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

function hasExpectedSignature(bytes: Uint8Array, type: ImageMimeType) {
  if (type === "image/jpeg") return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (type === "image/png") return bytes.length >= 8 && [137, 80, 78, 71, 13, 10, 26, 10].every((value, index) => bytes[index] === value);
  return bytes.length >= 12 && String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" && String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
}

export async function validateImageUpload(file: FormDataEntryValue | null) {
  if (!(file instanceof File) || file.size === 0) return null;
  if (!IMAGE_MIME_TYPES.includes(file.type as ImageMimeType)) throw new Error("Choose a JPEG, PNG, or WebP image.");
  if (file.size > MAX_IMAGE_BYTES) throw new Error("Images must be 5 MB or smaller.");
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  if (!hasExpectedSignature(bytes, file.type as ImageMimeType)) throw new Error("The image file does not match its declared type.");
  return file;
}

export function imagePath(scope: "avatar" | "content", recordId: string, mimeType: ImageMimeType, kind?: "page" | "news" | "event") {
  if (!OWNER_ID_PATTERN.test(recordId)) throw new Error("Image storage owner must be a UUID.");
  if (scope === "content" && !kind) throw new Error("Content image kind is required.");
  const prefix = scope === "avatar" ? `avatars/${recordId}` : `content/${kind}/${recordId}`;
  return `${prefix}/${randomUUID()}.${extensions[mimeType]}`;
}
