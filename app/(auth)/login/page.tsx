import Link from "next/link";
import { AuthForm } from "@/components/auth-form";
export default function LoginPage() { return <><AuthForm title="School login" description="Sign in with your approved Little Gems account." buttonLabel="Sign in" mode="login" /><p className="mx-auto -mt-8 w-full max-w-md px-6 pb-8"><Link href="/">School homepage</Link> · New student? <Link href="/signup">Register safely</Link></p></>; }
