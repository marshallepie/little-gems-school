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
  return <main className="mx-auto max-w-md space-y-6"><h1 className="text-3xl font-bold">{title}</h1><p>{description}</p><form className="space-y-4" action={submit}><label className="block font-medium">Email<input name="email" className="mt-1 w-full rounded border p-3" type="email" required={mode !== "update"} autoComplete="email" /></label>{needsPassword && <label className="block font-medium">Password<input name="password" className="mt-1 w-full rounded border p-3" type="password" required minLength={8} autoComplete={mode === "login" ? "current-password" : "new-password"} /></label>}<button className="primary-cta min-h-11 rounded px-4 py-2 font-semibold" disabled={pending} type="submit">{pending ? "Please wait…" : buttonLabel}</button></form>{notice && <p className="rounded border border-amber-300 bg-amber-50 p-3" role="status">{notice}</p>}</main>;
}
