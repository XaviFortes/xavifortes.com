import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import tailwind from "@astrojs/tailwind";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://xavifortes.com",
  integrations: [
    mdx(),
    tailwind({
      applyBaseStyles: false,
    }),
    sitemap({
      // Sitemaps list pages, not feeds/data endpoints.
      filter: (page) =>
        !page.endsWith("rss.xml") && !page.endsWith("iocs.json"),
    }),
  ],
});
