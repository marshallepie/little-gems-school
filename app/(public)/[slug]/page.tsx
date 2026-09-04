import { notFound } from "next/navigation";
import { PublicPage } from "@/components/public-site";
import { getPublishedPage } from "@/lib/public-content";

export const revalidate = 300;
export default async function ManagedPage({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const page = await getPublishedPage(slug);
  if (!page) notFound();
  return <PublicPage eyebrow="Little Gems" title={page.title}><article className="mt-8 max-w-3xl space-y-4 whitespace-pre-wrap leading-7">{page.summary && <p className="text-xl font-medium">{page.summary}</p>}<p>{page.body}</p></article></PublicPage>;
}
