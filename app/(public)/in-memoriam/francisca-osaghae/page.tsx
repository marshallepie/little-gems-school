import type { Metadata } from "next";
import Image from "next/image";

export const metadata: Metadata = {
  title: "In Loving Memory of Mrs. Francisca Ojoryemi Osaghae (née Anumudu)",
  description: "Memorial notice for Mrs. Francisca Ojoryemi Osaghae (née Anumudu), 1971–2026.",
  openGraph: {
    title: "In Loving Memory of Mrs. Francisca Ojoryemi Osaghae (née Anumudu)",
    description: "Memorial notice from Little Gems Private School.",
    images: [{ url: "/images/francisca-osaghae-portrait-clean.webp", width: 630, height: 1380, alt: "Portrait of Mrs. Francisca Ojoryemi Osaghae" }],
  },
};

function ServiceDetails({ children, title }: Readonly<{ children: React.ReactNode; title: string }>) {
  return (
    <section className="rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
      <h2 className="text-xl font-bold text-slate-900">{title}</h2>
      <div className="mt-4 space-y-3 text-slate-700">{children}</div>
    </section>
  );
}

function Tribute({ attribution, byline, children, title }: Readonly<{ attribution: string; byline: string; children: React.ReactNode; title: string }>) {
  return (
    <section aria-labelledby={`tribute-${title}`} className="rounded-2xl border border-violet-100 bg-violet-50/40 p-6 sm:p-8">
      <h2 id={`tribute-${title}`} className="text-2xl font-bold text-slate-950">{title}</h2>
      <p className="mt-2 font-medium text-slate-700">{byline}</p>
      <div className="mt-6 space-y-5 text-lg leading-8 text-slate-700">{children}</div>
      <p className="mt-7 font-semibold text-slate-900">{attribution}</p>
    </section>
  );
}

export default function FranciscaOsaghaeMemorialPage() {
  return (
    <main id="main-content" className="mx-auto max-w-6xl px-4 py-10 sm:px-6 sm:py-14">
      <div className="mx-auto max-w-4xl">
        <p className="text-center text-sm font-semibold uppercase tracking-[0.2em] text-violet-800">In memoriam</p>
        <h1 className="mx-auto mt-4 max-w-3xl text-center text-4xl font-bold tracking-tight text-slate-950 sm:text-5xl">In Loving Memory of Mrs. Francisca Ojoryemi Osaghae (née Anumudu)</h1>
        <p className="mt-5 text-center text-lg text-slate-700">Aged 55 years · <time dateTime="2026-09-11">11 September 2026</time></p>
      </div>

      <div className="mx-auto mt-10 grid max-w-5xl items-start gap-8 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)]">
        <figure className="mx-auto w-full max-w-sm">
          <div className="overflow-hidden rounded-2xl border border-slate-200 bg-white p-2 shadow-sm">
            <Image alt="Portrait of Mrs. Francisca Ojoryemi Osaghae" className="aspect-[4/5] w-full rounded-xl object-cover object-top" height={1380} priority src="/images/francisca-osaghae-portrait-clean.webp" width={630} />
          </div>
        </figure>
        <section aria-label="Memorial notice" className="space-y-6">
          <div className="border-l-4 border-violet-800 pl-5 text-lg leading-8 text-slate-700">
            <p>Little Gems Private School respectfully shares this memorial notice for Mrs. Francisca Ojoryemi Osaghae (née Anumudu).</p>
          </div>
          <div className="grid gap-5 sm:grid-cols-2">
            <ServiceDetails title="Service of Songs">
              <p><time dateTime="2026-09-25T16:00:00+01:00">Friday, 25 September 2026, 4:00 pm</time></p>
              <p>Grace Hall, MFM HQ, Onike, Yaba, Lagos.</p>
            </ServiceDetails>
            <ServiceDetails title="Funeral Service and Interment">
              <p><time dateTime="2026-10-02T10:00:00+01:00">Friday, 2 October 2026, 10:00 am</time></p>
              <p>Pa Philips Anumudu Compound, Ebu Omor, Oshimili North, Delta State, Nigeria.</p>
            </ServiceDetails>
          </div>
        </section>
      </div>

      <div className="mx-auto mt-12 max-w-4xl space-y-8">
        <Tribute attribution="Proprietress, Little Gems Private School" byline="From the Proprietress, Little Gems Private School" title="PERSONAL TRIBUTE">
          <p>My dear Francisca,</p>
          <p>It is with a heavy heart that I write this. I am yet to come to terms with the news of your passing. You were not just a staff to me but a daughter also. For many years, you served this school with uncommon dedication, loyalty and love. You gave your best to our children as if they were your own.</p>
          <p>I loved you sincerely, and you knew it. Your humility, your calm spirit, your respectful manner and your selfless heart stood out. You never made a fuss about anything. You did your work quietly and excellently.</p>
          <p>Your departure has left a deep hole in my heart and in the Little Gems family. It hurts so much, but I am comforted that you lived a good life, touched lives, and served God faithfully. Rest well, my dear. Your memories will never fade. Your labour of love will never be forgotten.</p>
          <p>May the good Lord grant you eternal rest and give your husband and entire family the fortitude to bear this painful loss. I will always love and miss you.</p>
          <p>Adieu, Francisca.</p>
        </Tribute>

        <Tribute attribution="Management & Staff, Little Gems Private School" byline="By Little Gems Private School" title="TRIBUTE TO A DEDICATED STAFF AND A MODEL OF NOBLE CHARACTER">
          <p>The memory of our dear Mrs. Francisca Osaghae (Nee Anumudu) will forever remain in our hearts.</p>
          <p>She was the epitome of humility and selflessness; the true definition of a noble character. She was easy-going, gentle in spirit, and faced even the most difficult moments of life with grace and calmness, without complaint.</p>
          <p>Though we mourn her passing deeply, we are consoled by her lasting legacies: her positive impact on humanity, especially on the young scholars she nurtured with love, her dedicated service to God, and our firm faith that she now rests in a better place.</p>
          <p>May the Almighty God, whom she served so faithfully, comfort and strengthen her dear husband, children, siblings, friends, and the entire family.</p>
          <p>Adieu, &quot;Our Lady.&quot; You will be greatly missed.</p>
        </Tribute>
      </div>
    </main>
  );
}
