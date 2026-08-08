import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import sitemap from "@astrojs/sitemap";

// Tailwind is wired via postcss.config.mjs, not @astrojs/tailwind — that
// integration's peerDependencies cap out at Astro 5 and it was never updated
// for 6/7. Plain PostCSS is the officially recommended path for Tailwind v3
// on modern Astro; the @tailwind directives already live in global.css.
export default defineConfig({
  site: "https://xavifortes.com",
  integrations: [
    mdx(),
    sitemap({
      // Sitemaps list pages, not feeds/data endpoints.
      filter: (page) =>
        !page.endsWith("rss.xml") && !page.endsWith("iocs.json"),
    }),
  ],
});
