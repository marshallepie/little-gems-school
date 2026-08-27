import Link from "next/link";

export default function HomePage() {
  return <main className="space-y-8"><header><p className="font-semibold text-violet-700">Little Gems School</p><h1 className="mt-2 text-4xl font-bold">A secure school portal is being prepared.</h1></header><p className="max-w-2xl text-lg">This foundation establishes the public entry point and secure portal boundary. School operations and public content will follow approved milestones.</p><Link className="inline-block rounded bg-violet-700 px-4 py-2 font-semibold text-white no-underline" href="/login">School login</Link></main>;
}
