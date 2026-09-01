import "server-only";

import { createClient } from "@supabase/supabase-js";

/**
 * Server-only Supabase client for Auth administration. Do not import from client
 * components and never expose this key through NEXT_PUBLIC_* environment variables.
 */
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new Error("Server-side account administration is not configured.");
  }

  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}
