import Image from "next/image";
import Link from "next/link";

export default function HomePage() {
  return (
    <main className="py-4 sm:py-8 lg:py-12">
      <section className="max-w-2xl space-y-8">
        <header className="space-y-4">
          <Image
            alt="Little Gems School crest featuring a graduation cap, book, and the motto Winning from the Start"
            className="h-auto w-28 object-contain sm:w-32 md:w-36"
            height={528}
            priority
            sizes="(max-width: 640px) 7rem, (max-width: 768px) 8rem, 9rem"
            src="/images/little-gems-school-logo.jpg"
            width={528}
          />
          <div>
            <p className="font-semibold text-violet-700">Little Gems School</p>
            <h1 className="mt-2 text-3xl font-bold sm:text-4xl">A secure school portal is being prepared.</h1>
          </div>
        </header>
        <p className="text-lg">
          This foundation establishes the public entry point and secure portal boundary. School operations and public content will follow approved milestones.
        </p>
        <Link
          className="primary-cta inline-block rounded px-4 py-2 font-semibold no-underline"
          href="/login"
        >
          School login
        </Link>
      </section>
    </main>
  );
}
