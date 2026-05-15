# Authoring conventions

## File and content rules

- One post per `.org` file in `org/posts/`. Filename slug becomes the URL slug. Use kebab-case (`raytracing-from-scratch.org`).
- The org file is the source of truth. Never hand-edit the generated `.mdx` in `src/content/blog/`. The conversion script overwrites it.
- Generated MDX files are committed to the repo so the site builds without pandoc/emacs available in CI.
- Each generated MDX file begins with the comment `{/* Generated from org/posts/<slug>.org. Do not edit. */}` immediately after the frontmatter.

## Required frontmatter (org keywords)

Every post must declare:

- `#+TITLE:` — post title, 1–120 chars
- `#+DESCRIPTION:` — 20–200 chars, used for meta description, RSS, and social previews
- `#+DATE:` — ISO date `YYYY-MM-DD`

Optional:

- `#+UPDATED:` — ISO date, must be ≥ `#+DATE`
- `#+TAGS:` — comma-or-space-separated, lowercased on conversion
- `#+DRAFT: t` — excludes from production builds
- `#+OG_IMAGE:` — path to a custom Open Graph image

The conversion script must fail loudly with a clear error message if any required keyword is missing.

## Auto-detected frontmatter

The conversion script sets these by scanning content; don't add them by hand:

- `math: true` if the file contains `\(`, `\[`, or `$$...$$`
- `hasDemos: true` if the file contains a `#+BEGIN_EXPORT mdx` block

## Top-level structure

The org file's `#+TITLE:` is the post title; do not repeat it as a heading in the body. Use `*` for top-level body headings (the conversion uses `--shift-heading-level-by=1` so `*` becomes `<h2>` in output — `<h1>` is reserved for the title rendered by the template).

## Math

Write inline math in org as `\(...\)` and display math as `\[...\]`. Pandoc rewrites both into `$...$` / `$$...$$` in the generated MDX, and KaTeX renders them at build time. Do not author math in org with `$...$` or `$$...$$` — it creates ambiguity with literal dollar signs in the source.

## Code blocks

```org
#+BEGIN_SRC python :results output
import numpy as np
print(np.linspace(0, 1, 5))
#+END_SRC
```

If using `:results`, **evaluate the buffer before committing** so output is baked into the file. Either:
- Interactively: `C-c C-v b` in Emacs, then save.
- Via build: run `make eval-babel` (uses Emacs in batch mode, calls `scripts/eval-babel.el`).

CI does not run babel; only pre-evaluated content ships.

## Interactive demos

Embed via raw MDX export blocks:

```org
#+BEGIN_EXPORT mdx
import RayMarcher from '../../components/demos/RayMarcher.tsx';

<RayMarcher steps={64} client:visible />
#+END_EXPORT
```

Demo components live in `src/components/demos/`. Always pass a `client:*` directive (default to `client:visible` for below-the-fold demos, `client:load` only when interaction must be immediate). Provide a sensible fallback or poster image inside the component for users with JS disabled.

## Images and assets

Reference assets in org as `[[file:../assets/<slug>/<file>.png]]`. The conversion script:
1. Copies `org/assets/<slug>/` to `public/blog-assets/<slug>/`.
2. Rewrites the link in the MDX to `/blog-assets/<slug>/<file>.png`.

## Callouts

Use a custom Astro component for notes/warnings/asides. Import inside an `#+BEGIN_EXPORT mdx` block:

```org
#+BEGIN_EXPORT mdx
import Callout from '../../components/ui/Callout.astro';

<Callout type="note">
  Sentence-level prose lives here.
</Callout>
#+END_EXPORT
```

Supported `type` values: `note`, `warning`, `aside`.
