import type { APIRoute } from "astro";
import { getCollection } from "astro:content";

/**
 * Machine-readable indicator export.
 *
 * Values here are NOT defanged — this endpoint exists so other people's tooling
 * can ingest them directly. The HTML pages defang everything; this is the
 * deliberate exception, served as application/json rather than as clickable
 * links.
 */
export const GET: APIRoute = async ({ site }) => {
  const base = site ?? new URL("https://xavifortes.com");

  const posts = (
    await getCollection("research", ({ data }) => !data.draft)
  ).sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());

  const body = {
    generated: new Date().toISOString(),
    source: new URL("research/", base).toString(),
    license: "CC BY 4.0",
    reports: posts
      .filter((p) => p.data.iocs.length > 0 || p.data.samples.length > 0)
      .map((p) => ({
        id: p.slug,
        title: p.data.title,
        url: new URL(`research/${p.slug}/`, base).toString(),
        published: p.data.pubDate.toISOString().slice(0, 10),
        malware_family: p.data.malwareFamily ?? null,
        first_seen: p.data.firstSeen?.toISOString().slice(0, 10) ?? null,
        tags: p.data.tags,
        samples: p.data.samples,
        iocs: p.data.iocs,
      })),
  };

  return new Response(JSON.stringify(body, null, 2), {
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
    },
  });
};
