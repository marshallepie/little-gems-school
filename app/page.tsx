import Image from "next/image";
import Link from "next/link";

export default function HomePage() {
  return (
    <main className="grid items-center gap-10 py-4 lg:grid-cols-[minmax(0,1fr)_minmax(18rem,0.8fr)] lg:gap-16 lg:py-12">
      <section className="space-y-8">
        <header>
          <p className="font-semibold text-violet-700">Little Gems School</p>
          <h1 className="mt-2 text-4xl font-bold">A secure school portal is being prepared.</h1>
        </header>
        <p className="max-w-2xl text-lg">
          This foundation establishes the public entry point and secure portal boundary. School operations and public content will follow approved milestones.
        </p>
        <Link
          className="inline-block rounded bg-violet-700 px-4 py-2 font-semibold text-white no-underline transition-colors hover:bg-violet-800 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-700"
          href="/login"
        >
          School login
        </Link>
      </section>

      <div className="justify-self-center rounded-3xl bg-white p-4 shadow-sm ring-1 ring-violet-100 sm:p-6">
        <Image
          alt="Little Gems School crest featuring a graduation cap, book, and the motto Winning from the Start"
          className="h-auto w-full max-w-sm object-contain"
          height={528}
          priority
          src="/images/little-gems-school-logo.jpg"
          width={528}
        />
      </div>
    </main>
  );
}
