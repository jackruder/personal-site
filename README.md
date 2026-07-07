# personal-site

A static personal landing page and technical blog built with Astro, authored primarily in org-mode, converted to committed MDX for reproducible builds, and designed to deploy as plain static files to a home server.

## Quickstart

1. Clone the repository.
2. Get a Node 22.12+ toolchain. Either:
   - Install Node 22 and `pnpm` yourself, or
   - `nix develop` to drop into a shell with both (from `flake.nix`).
3. Run `pnpm install`.
4. Run `make dev`.

The Makefile also auto-wraps `pnpm`/`rsync` invocations in `nix develop --command …` when they aren't on `PATH`, so `make build`/`make deploy` work without entering the devShell first.

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
- See `DEPLOYMENT.org` for the step-by-step guide to taking it live.
- See `DESIGN.md` for the architectural choices and deferred features.
