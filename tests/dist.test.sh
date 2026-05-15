#!/usr/bin/env bash
# Smoke checks against the built dist/ directory. Run after `make build`.
# Each assertion guards a regression we've actually seen in this repo.

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -d dist ]]; then
  echo "dist/ does not exist; run 'make build' first" >&2
  exit 1
fi

pass=0
fail=0
failed_names=()

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok  - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name"
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
}

theme_script_present() {
  # Regression: the inline theme script previously rendered the literal
  # text `{themeScript}` instead of the IIFE body.
  grep -q "localStorage.getItem('theme')" dist/blog/hello-world/index.html \
    && ! grep -q '{themeScript}' dist/blog/hello-world/index.html
}

rss_has_items() {
  # Regression: hasDemos over-eager detection emptied the feed.
  grep -q '<item>' dist/rss.xml
}

sitemap_exists() {
  [[ -f dist/sitemap-index.xml ]]
}

og_title_is_bare() {
  # Regression: og:title was "Hello world · Blog" instead of "Hello world".
  grep -q 'property="og:title" content="Hello world"' dist/blog/hello-world/index.html
}

katex_rendered_server_side() {
  # If KaTeX SSR breaks, math falls back to raw `$...$` text.
  grep -q 'class="katex"' dist/blog/hello-world/index.html
}

post_route_exists() {
  [[ -f dist/blog/hello-world/index.html ]]
}

check "post route built" post_route_exists
check "theme script body inlined" theme_script_present
check "rss feed has items" rss_has_items
check "sitemap generated" sitemap_exists
check "og:title is bare post title" og_title_is_bare
check "katex rendered at build time" katex_rendered_server_side

echo
echo "$pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  printf '  - %s\n' "${failed_names[@]}" >&2
  exit 1
fi
