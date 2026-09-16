"use client";

import Link from "next/link";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/browser";

type AuthFormProps = { title: string; description: string; buttonLabel: string; mode: "login" | "reset" | "update" };

export function AuthForm({ title, description, buttonLabel, mode }: AuthFormProps) {
  const [notice, setNotice] = useState<string | null>(null);
  const [isError, setIsError] = useState(false);
  const [pending, setPending] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);
  const router = useRouter();
  const needsPassword = mode !== "reset";

  function showNotice(message: string, error = false) {
    setIsError(error);
    setNotice(message);
  }

  async function submit(formData: FormData) {
    setPending(true);
    setNotice(null);
    setIsError(false);
    try {
      const supabase = createClient();
      const email = String(formData.get("email") ?? "").trim();
      const password = String(formData.get("password") ?? "");
      const passwordConfirmation = String(formData.get("passwordConfirmation") ?? "");
      if (mode === "login") {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        router.replace("/dashboard");
        router.refresh();
        return;
      }
      if (mode === "reset") {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/update-password` });
        if (error) throw error;
        showNotice("If this account exists, a reset link has been sent.");
        return;
      }
      if (password !== passwordConfirmation) {
        showNotice("The new password and confirmation do not match.", true);
        return;
      }
      // Supabase only accepts this mutation with a current authenticated or recovery session.
      const { data: userData, error: userError } = await supabase.auth.getUser();
      if (userError || !userData.user) {
        showNotice("Open a valid password-reset link, or sign in before changing your password.", true);
        return;
      }
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      showNotice("Password updated. You can now continue to your portal.");
    } catch (error) {
      showNotice(error instanceof Error ? error.message : "Unable to complete that request.", true);
    } finally {
      setPending(false);
    }
  }

  const passwordType = showPassword ? "text" : "password";
  return <main className="mx-auto w-full max-w-md px-3 py-6 sm:px-6 sm:py-10"><div className="min-w-0 space-y-6 rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200 sm:p-6"><h1 className="break-words text-2xl font-bold sm:text-3xl">{title}</h1><p className="break-words">{description}</p><form className="space-y-4" action={submit}><label className="block min-w-0 font-medium">Email<input name="email" className="mt-1 min-h-11 w-full min-w-0 rounded border border-slate-400 p-3 text-base" type="email" required={mode !== "update"} autoComplete="email" inputMode="email" disabled={mode === "update"} /></label>{needsPassword && <div className="space-y-1"><label className="block min-w-0 font-medium" htmlFor="password">{mode === "update" ? "New password" : "Password"}</label><div className="flex gap-2"><input id="password" name="password" className="min-h-11 min-w-0 flex-1 rounded border border-slate-400 p-3 text-base" type={passwordType} required minLength={8} autoComplete={mode === "login" ? "current-password" : "new-password"} /><button className="min-h-11 shrink-0 rounded border-2 border-slate-700 px-3 py-2 font-semibold" type="button" onClick={() => setShowPassword((visible) => !visible)} aria-pressed={showPassword}>{showPassword ? "Hide password" : "Show password"}</button></div></div>}{mode === "login" && <Link className="inline-block min-h-11 py-2 font-semibold" href="/forgot-password">Forgot password?</Link>}{mode === "update" && <div className="space-y-1"><label className="block min-w-0 font-medium" htmlFor="password-confirmation">Confirm new password</label><div className="flex gap-2"><input id="password-confirmation" name="passwordConfirmation" className="min-h-11 min-w-0 flex-1 rounded border border-slate-400 p-3 text-base" type={showConfirmation ? "text" : "password"} required minLength={8} autoComplete="new-password" /><button className="min-h-11 shrink-0 rounded border-2 border-slate-700 px-3 py-2 font-semibold" type="button" onClick={() => setShowConfirmation((visible) => !visible)} aria-pressed={showConfirmation}>{showConfirmation ? "Hide password" : "Show password"}</button></div></div>}<button className="primary-cta min-h-11 w-full rounded px-4 py-2 font-semibold sm:w-auto" disabled={pending} type="submit">{pending ? "Please wait…" : buttonLabel}</button></form>{notice && <p className={`break-words rounded border p-3 ${isError ? "border-red-300 bg-red-50 text-red-900" : "border-green-300 bg-green-50 text-green-900"}`} role={isError ? "alert" : "status"} aria-live="polite">{notice}</p>}<p className="text-sm text-slate-700"><strong>Need help?</strong> Use the password reset link for sign-in access. For school account information, contact the school through its usual approved channel.</p></div></main>;
}
