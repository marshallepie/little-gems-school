"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/browser";

export function PortalAccountControls() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [isSigningOut, setIsSigningOut] = useState(false);

  async function signOut() {
    setError(null);
    setIsSigningOut(true);
    try {
      const { error: signOutError } = await createClient().auth.signOut();
      if (signOutError) {
        setError("We could not sign you out. Please try again.");
        return;
      }
      router.replace("/login");
      router.refresh();
    } catch {
      setError("We could not sign you out. Please try again.");
    } finally {
      setIsSigningOut(false);
    }
  }

  return <nav className="flex flex-wrap items-center gap-2" aria-label="Account actions">
    <Link className="min-h-11 rounded border-2 border-slate-700 bg-white px-3 py-2 font-semibold text-slate-950 no-underline hover:bg-slate-100" href="/profile" prefetch={false}>Profile & security</Link>
    <button className="min-h-11 rounded border-2 border-slate-700 bg-white px-3 py-2 font-semibold text-slate-950 hover:bg-slate-100 disabled:cursor-not-allowed disabled:opacity-60" disabled={isSigningOut} onClick={signOut} type="button">{isSigningOut ? "Signing out…" : "Sign out"}</button>
    {error && <p className="basis-full text-sm font-semibold text-red-800" role="alert">{error}</p>}
  </nav>;
}
