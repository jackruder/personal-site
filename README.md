# personal-site

A static personal landing page and technical blog built with Astro, authored primarily in org-mode, converted to committed MDX for reproducible builds, and designed to deploy as plain static files to a home server.

## Quickstart

1. Clone the repository.
2. Use Node.js 22.12+ locally.
3. Run `pnpm install`.
4. Run `make dev`.

## Writing a new post

1. Copy `org/posts/template.org` to a new kebab-case filename in `org/posts/`.
2. Edit the org frontmatter and body.
3. Run `make build`.

## Tests

`make test` runs both suites:

- `make test-script` — shell tests for the org-to-MDX conversion (requires `pandoc`).
- `make test-dist` — smoke checks against the built `dist/` (builds first if needed).

## More documentation

- See `AUTHORING.md` for authoring conventions and the org-to-MDX workflow.
- See `DESIGN.md` for the architectural choices and deferred features.
