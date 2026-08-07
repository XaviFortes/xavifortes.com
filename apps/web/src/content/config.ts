import { defineCollection, z } from "astro:content";

/**
 * Research collection.
 *
 * IOC values are stored undefanged so /research/iocs.json can serve them to
 * tooling verbatim. They are defanged at render time by defang() in
 * src/lib/defang.ts, so nothing clickable ever lands in the HTML. Keep it that
 * way — a page full of live C2 URLs is a good way to get the domain
 * categorised as malicious.
 */

const iocType = z.enum([
  "domain",
  "url",
  "ip",
  "ip:port",
  "sha256",
  "sha1",
  "md5",
  "mutex",
  "path",
  "registry",
  "useragent",
  "email",
]);

const research = defineCollection({
  type: "content",
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),

    malwareFamily: z.string().optional(),
    firstSeen: z.coerce.date().optional(),

    samples: z
      .array(
        z.object({
          name: z.string(),
          sha256: z
            .string()
            .regex(/^[a-fA-F0-9]{64}$/, "sha256 must be 64 hex characters"),
          size: z.number().int().positive().optional(),
          note: z.string().optional(),
          url: z.string().url().optional(),
        }),
      )
      .default([]),

    iocs: z
      .array(
        z.object({
          value: z.string(),
          type: iocType,
          note: z.string().optional(),
        }),
      )
      .default([]),

    references: z
      .array(z.object({ title: z.string(), url: z.string().url() }))
      .default([]),
  }),
});

export const collections = { research };
