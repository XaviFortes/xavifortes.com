import { defineConfig } from "astro/config";
import mdx from "@astrojs/mdx";
import tailwind from "@astrojs/tailwind";

// NOTE: @astrojs/sitemap 3.7.x requires Astro 5 — it reads `routes` from the
// astro:build:done hook, which Astro 4 doesn't provide, and its package.json
// declares no peerDependencies so npm installs it without warning.
// Re-enable after either `npm i @astrojs/sitemap@3.2.1` or upgrading to Astro 5.
export default defineConfig({
  site: "https://xavifortes.com",
  integrations: [
    mdx(),
    tailwind({
      applyBaseStyles: false,
    }),
  ],
});
