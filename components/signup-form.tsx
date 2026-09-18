"use client";

import Link from "next/link";
import { useState } from "react";
import { createClient } from "@/lib/supabase/browser";

const MIN_PASSWORD_LENGTH = 12;
/** A fixed same-origin landing route; never accept a redirect from URL/FormData. */
function confirmationRedirect() { return `${window.location.origin}/login`; }

export function SignupForm() {
  const [notice, setNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  async function submit(formData: FormData) {
    const email = String(formData.get("email") ?? "").trim();
    const password = String(formData.get("password") ?? "");
    const confirmation = String(formData.get("passwordConfirmation") ?? "");
    setError(null); setNotice(null);
    if (password.length < MIN_PASSWORD_LENGTH) { setError(`Choose a password of at least ${MIN_PASSWORD_LENGTH} characters.`); return; }
    if (password !== confirmation) { setError("Password and confirmation do not match."); return; }
    setPending(true);
    try {
      const { error: signUpError } = await createClient().auth.signUp({ email, password, options: { emailRedirectTo: confirmationRedirect() } });
      // Do not distinguish an existing email from a newly registered address.
      if (signUpError) throw signUpError;
      setNotice("If registration can be completed, check your email for the confirmation link. After confirmation, wait for school admission before portal access is available.");
    } catch { setNotice("If registration can be completed, check your email for the confirmation link. After confirmation, wait for school admission before portal access is available."); }
    finally { setPending(false); }
  }
  return <main className="mx-auto w-full max-w-md px-3 py-6 sm:px-6 sm:py-10"><div className="space-y-5 rounded-xl bg-white p-5 shadow-sm ring-1 ring-slate-200"><Link className="font-semibold" href="/">← School homepage</Link><h1 className="text-3xl font-bold">Student registration</h1><p>Register your own password. Registration does not create a portal role, school record, or access to pupil information.</p><form action={submit} className="space-y-4"><label className="block font-medium">Email<input className="mt-1 min-h-11 w-full rounded border p-3" name="email" type="email" autoComplete="email" required /></label><label className="block font-medium">Password<input className="mt-1 min-h-11 w-full rounded border p-3" name="password" type="password" autoComplete="new-password" minLength={MIN_PASSWORD_LENGTH} required /></label><label className="block font-medium">Confirm password<input className="mt-1 min-h-11 w-full rounded border p-3" name="passwordConfirmation" type="password" autoComplete="new-password" minLength={MIN_PASSWORD_LENGTH} required /></label><button className="primary-cta min-h-11 rounded px-4 py-2 font-semibold disabled:opacity-60" disabled={pending}>{pending ? "Registering…" : "Register"}</button></form>{error && <p role="alert" className="text-red-800">{error}</p>}{notice && <p role="status">{notice}</p>}<p>Already have an approved account? <Link href="/login">Sign in</Link></p></div></main>;
}
