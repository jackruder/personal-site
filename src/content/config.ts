import { defineCollection, z } from 'astro:content';

export const blogSchema = z.object({
  title: z.string().min(1).max(120),
  description: z.string().min(20).max(200),
  pubDate: z.coerce.date(),
  updatedDate: z.coerce.date().optional(),
  tags: z.array(z.string().toLowerCase()).default([]),
  draft: z.boolean().default(false),
  math: z.boolean().default(false),
  hasDemos: z.boolean().default(false),
  ogImage: z.string().optional(),
  canonical: z.string().url().optional(),
})
.refine(
  (data) => !data.updatedDate || data.updatedDate >= data.pubDate,
  { message: 'updatedDate must be after pubDate' }
);

const blog = defineCollection({
  type: 'content',
  schema: blogSchema,
});

export const collections = { blog };
