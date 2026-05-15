# Design decisions

## Why Astro

Astro is a good fit for this site because it supports island architecture, MDX, content collections, and static output without adding a server runtime. That keeps the landing page fast while still allowing interactive demos to hydrate only where needed.

## Why org as the source format

Org-mode is the source format because it is richer than plain Markdown, supports babel, handles footnotes well, and comes with mature tooling for long-form technical writing. That makes it practical to keep research notes and blog posts in one authoring style.

## Why pandoc instead of ox-hugo or ox-md

Pandoc is the conversion layer because it produces neutral output, is easy to script, and avoids coupling the content pipeline to Hugo-specific conventions. The goal is MDX that fits Astro rather than a generator-specific export format.

## Why generated MDX is committed

Generated MDX is committed so CI can build the site without pandoc or Emacs, and so the repo preserves reproducible build artifacts for each post revision. The org file remains the source of truth, but the generated output stays available for static builds everywhere.

## Why React as the demo framework

React is the default framework for demos because it is well supported in Astro and is a common baseline for interactive experiments. It can be swapped or extended later if Svelte or another framework becomes a better fit.

## Why no CSS framework

A CSS framework is intentionally omitted because this is a small site and plain CSS is easier to read and maintain than a utility framework at this scale. The design needs are modest enough that custom properties and a small stylesheet are sufficient.

## Why home-server + Cloudflare

A home server keeps deployment and hosting under direct control, while Cloudflare can add caching, TLS, and basic DDoS protection at low cost. The combination preserves flexibility without forcing a platform-specific runtime.

## Deferred features

- Comments (Giscus): add when there is enough post traffic to justify reader discussion.
- Search (Pagefind): add when the number of posts makes manual browsing inconvenient.
- Analytics (Plausible or log-parsing): add when there is a concrete question to answer about readership.
- Newsletter: add when there is a consistent publishing cadence worth subscribing to.
- Series support: add when posts start spanning multi-part narratives.
- Controlled tag vocabulary: add when ad hoc tags become inconsistent or hard to browse.
