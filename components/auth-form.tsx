"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/browser";

type AuthFormProps = { title: string; description: string; buttonLabel: string; mode: "login" | "reset" | "update" };
export function AuthForm({ title, description, buttonLabel, mode }: AuthFormProps) {
  const [notice, setNotice] = useState<string | null>(null);
  const [pending, setPending] = useState(false);
  const router = useRouter();
  const needsPassword = mode !== "reset";
  async function submit(formData: FormData) {
    setPending(true); setNotice(null);
    try {
      const supabase = createClient();
      const email = String(formData.get("email") ?? "");
      const password = String(formData.get("password") ?? "");
      if (mode === "login") {
        const { error } = await supabase.auth.signInWithPassword({ email, password });
        if (error) throw error;
        router.replace("/dashboard"); router.refresh(); return;
      }
      if (mode === "reset") {
        const { error } = await supabase.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/update-password` });
        if (error) throw error;
        setNotice("If this account exists, a reset link has been sent."); return;
      }
      const { error } = await supabase.auth.updateUser({ password });
      if (error) throw error;
      setNotice("Password updated. You can now continue to your portal.");
    } catch (error) { setNotice(error instanceof Error ? error.message : "Unable to complete that request."); }
    finally { setPending(false); }
  }
  return <main className="mx-auto w-full max-w-md px-3 py-6 sm:px-6 sm:py-10"><div className="min-w-0 space-y-6 rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200 sm:p-6"><h1 className="break-words text-2xl font-bold sm:text-3xl">{title}</h1><p className="break-words">{description}</p><form className="space-y-4" action={submit}><label className="block min-w-0 font-medium">Email<input name="email" className="mt-1 min-h-11 w-full min-w-0 rounded border border-slate-400 p-3 text-base" type="email" required={mode !== "update"} autoComplete="email" inputMode="email" /></label>{needsPassword && <label className="block min-w-0 font-medium">Password<input name="password" className="mt-1 min-h-11 w-full min-w-0 rounded border border-slate-400 p-3 text-base" type="password" required minLength={8} autoComplete={mode === "login" ? "current-password" : "new-password"} /></label>}<button className="primary-cta min-h-11 w-full rounded px-4 py-2 font-semibold sm:w-auto" disabled={pending} type="submit">{pending ? "Please wait…" : buttonLabel}</button></form>{notice && <p className="break-words rounded border border-amber-300 bg-amber-50 p-3" role="status">{notice}</p>}</div></main>;
}
