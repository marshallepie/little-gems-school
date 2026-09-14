type StorageCleanupError = { message?: string; statusCode?: string | number } | null;
type StorageBucket = { remove(paths: string[]): Promise<{ error: StorageCleanupError }> };

/**
 * Metadata writes remain authoritative. Failed best-effort deletion is logged with
 * stable, path-free fields so host logs can alert and operators can retry cleanup.
 */
export async function cleanupStorageObject(bucket: StorageBucket, bucketName: "cms-images" | "profile-avatars", path: string, operation: "replace" | "remove" | "rollback") {
  const { error } = await bucket.remove([path]);
  if (!error) return true;
  console.error("storage_cleanup_failed", {
    bucket: bucketName,
    operation,
    statusCode: error.statusCode ?? null,
    // Do not include signed URLs, object keys, or provider messages in logs.
    errorType: typeof error.message === "string" ? "provider_error" : "unknown_error",
  });
  return false;
}
