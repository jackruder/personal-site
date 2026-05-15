import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context) {
  const posts = (await getCollection('blog', ({ data }) => !data.draft))
    // TODO: revisit how interactive posts should appear in the feed.
    .filter((post) => !post.data.hasDemos)
    .sort((a, b) => b.data.pubDate.getTime() - a.data.pubDate.getTime());

  return rss({
    title: 'Jack Ruder — Blog',
    description: 'Technical writing and project notes by Jack Ruder.',
    site: context.site,
    items: posts.map((post) => ({
      title: post.data.title,
      description: post.data.description,
      pubDate: post.data.pubDate,
      link: `/blog/${post.id.replace(/\.mdx$/, '')}/`,
    })),
  });
}
