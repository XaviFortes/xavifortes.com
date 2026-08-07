import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { escapeXml } from "../../lib/defang";

/**
 * Full-content RSS feed, hand-rolled to avoid pulling in @astrojs/rss +
 * markdown-it + sanitize-html for one endpoint.
 *
 * Excerpt-only feeds get ignored by the aggregators that actually distribute
 * this kind of writing (malware.news among them), so the whole post body goes
 * in. Astro compiles the markdown at build time via import.meta.glob, and
 * compiledContent() hands back the rendered HTML as a string.
 */

const rendered = import.meta.glob<{ compiledContent: () => string }>(
  "../../content/research/*.md",
  { eager: true },
);

/** Map a collection entry id ("post.md") to its compiled HTML, if available. */
function htmlFor(id: string): string | null {
  const match = Object.entries(rendered).find(([path]) =>
    path.endsWith(`/${id}`),
  );
  try {
    return match?.[1]?.compiledContent?.() ?? null;
  } catch {
    return null;
  }
}

export const GET: APIRoute = async ({ site }) => {
  const base = site ?? new URL("https://xavifortes.com");

  const posts = (
    await getCollection("research", ({ data }) => !data.draft)
  ).sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());

  const items = posts
    .map((post) => {
      const url = new URL(`research/${post.slug}/`, base).toString();
      const html = htmlFor(post.id);
      const categories = post.data.tags
        .map((t) => `      <category>${escapeXml(t)}</category>`)
        .join("\n");

      return [
        "    <item>",
        `      <title>${escapeXml(post.data.title)}</title>`,
        `      <link>${escapeXml(url)}</link>`,
        `      <guid isPermaLink="true">${escapeXml(url)}</guid>`,
        `      <pubDate>${post.data.pubDate.toUTCString()}</pubDate>`,
        `      <description>${escapeXml(post.data.description)}</description>`,
        categories,
        html
          ? `      <content:encoded><![CDATA[${html.replace(/\]\]>/g, "]]&gt;")}]]></content:encoded>`
          : "",
        "    </item>",
      ]
        .filter(Boolean)
        .join("\n");
    })
    .join("\n");

  const now = new Date().toUTCString();

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"
     xmlns:content="http://purl.org/rss/1.0/modules/content/"
     xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <title>Xavier Fortes — Research</title>
    <link>${escapeXml(new URL("research/", base).toString())}</link>
    <description>Malware analysis and reverse engineering notes.</description>
    <language>en</language>
    <lastBuildDate>${now}</lastBuildDate>
    <atom:link href="${escapeXml(new URL("research/rss.xml", base).toString())}" rel="self" type="application/rss+xml" />
${items}
  </channel>
</rss>
`;

  return new Response(xml, {
    headers: { "Content-Type": "application/rss+xml; charset=utf-8" },
  });
};
