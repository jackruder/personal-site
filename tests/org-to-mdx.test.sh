#!/usr/bin/env bash
# Tests for scripts/org-to-mdx.sh.
# Each test runs in an isolated tempdir with org/assets, public/blog-assets,
# and src/content/blog laid out the way the script expects.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ORG_TO_MDX="$REPO_ROOT/scripts/org-to-mdx.sh"

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc not installed; skipping conversion tests" >&2
  exit 0
fi

pass=0
fail=0
failed_names=()

setup() {
  WORK="$(mktemp -d)"
  mkdir -p "$WORK/org/posts" "$WORK/org/assets" "$WORK/public/blog-assets" "$WORK/src/content/blog"
  cd "$WORK"
}

teardown() {
  cd "$REPO_ROOT"
  rm -rf "$WORK"
}

fail_test() {
  echo "    $1" >&2
  return 1
}

assert_contains() {
  local needle="$1" haystack="$2"
  grep -Fq -- "$needle" "$haystack" || fail_test "expected '$needle' in $haystack"
}

assert_not_contains() {
  local needle="$1" haystack="$2"
  if grep -Fq -- "$needle" "$haystack"; then
    fail_test "did not expect '$needle' in $haystack"
  fi
}

run_test() {
  local name="$1"
  setup
  if ( set -e; "$name" ); then
    echo "ok  - $name"
    pass=$((pass + 1))
  else
    echo "FAIL - $name"
    fail=$((fail + 1))
    failed_names+=("$name")
  fi
  teardown
}

# -- Fixtures --

write_minimal_post() {
  local path="$1"
  cat > "$path" <<'ORG'
#+TITLE: Sample
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

Body paragraph.
ORG
}

# -- Tests --

test_missing_title_fails() {
  cat > org/posts/x.org <<'ORG'
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01
body
ORG
  if "$ORG_TO_MDX" org/posts/x.org src/content/blog/x.mdx 2>err.txt; then
    fail_test "expected non-zero exit on missing #+TITLE"
  fi
  assert_contains "missing required keyword #+TITLE" err.txt
}

test_missing_description_fails() {
  cat > org/posts/x.org <<'ORG'
#+TITLE: Sample
#+DATE: 2026-01-01
body
ORG
  if "$ORG_TO_MDX" org/posts/x.org src/content/blog/x.mdx 2>err.txt; then
    fail_test "expected non-zero exit on missing #+DESCRIPTION"
  fi
  assert_contains "missing required keyword #+DESCRIPTION" err.txt
}

test_missing_date_fails() {
  cat > org/posts/x.org <<'ORG'
#+TITLE: Sample
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
body
ORG
  if "$ORG_TO_MDX" org/posts/x.org src/content/blog/x.mdx 2>err.txt; then
    fail_test "expected non-zero exit on missing #+DATE"
  fi
  assert_contains "missing required keyword #+DATE" err.txt
}

test_math_detected_paren() {
  cat > org/posts/m.org <<'ORG'
#+TITLE: Math
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

Inline \(a + b\) here.
ORG
  "$ORG_TO_MDX" org/posts/m.org src/content/blog/m.mdx
  assert_contains "math: true" src/content/blog/m.mdx
}

test_math_detected_bracket() {
  cat > org/posts/m.org <<'ORG'
#+TITLE: Math
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

\[
x = 1
\]
ORG
  "$ORG_TO_MDX" org/posts/m.org src/content/blog/m.mdx
  assert_contains "math: true" src/content/blog/m.mdx
}

test_math_false_when_absent() {
  write_minimal_post org/posts/p.org
  "$ORG_TO_MDX" org/posts/p.org src/content/blog/p.mdx
  assert_contains "math: false" src/content/blog/p.mdx
}

# Regression: a Callout-only #+BEGIN_EXPORT mdx block must NOT mark the post
# as hasDemos. The old grep also matched these, which excluded the seed post
# from the RSS feed.
test_hasdemos_false_for_callout_only_mdx_block() {
  cat > org/posts/c.org <<'ORG'
#+TITLE: Callout post
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

Body.

#+BEGIN_EXPORT mdx
import Callout from '../../components/ui/Callout.astro';

<Callout type="note">Just a note.</Callout>
#+END_EXPORT
ORG
  "$ORG_TO_MDX" org/posts/c.org src/content/blog/c.mdx
  assert_contains "hasDemos: false" src/content/blog/c.mdx
}

test_hasdemos_true_for_client_directive() {
  cat > org/posts/d.org <<'ORG'
#+TITLE: Demo post
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

Body.

#+BEGIN_EXPORT mdx
import Demo from '../../components/demos/Demo.tsx';

<Demo client:visible />
#+END_EXPORT
ORG
  "$ORG_TO_MDX" org/posts/d.org src/content/blog/d.mdx
  assert_contains "hasDemos: true" src/content/blog/d.mdx
}

# Regression: org `*` (level-1) must shift to MDX `##` (level-2) so the
# template `<h1>` stays reserved for the post title.
test_heading_shift_plus_one() {
  cat > org/posts/h.org <<'ORG'
#+TITLE: Headings
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

* Section heading

Body paragraph.

** Subsection heading

More body.
ORG
  "$ORG_TO_MDX" org/posts/h.org src/content/blog/h.mdx
  assert_contains "## Section heading" src/content/blog/h.mdx
  assert_contains "### Subsection heading" src/content/blog/h.mdx
  if grep -Eq '^# [^#]' src/content/blog/h.mdx; then
    fail_test "did not expect any H1 heading in src/content/blog/h.mdx"
  fi
}

test_assets_copied_and_links_rewritten() {
  mkdir -p org/assets/imgpost
  printf 'fake-png' > org/assets/imgpost/diagram.png
  cat > org/posts/imgpost.org <<'ORG'
#+TITLE: With image
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01

[[file:../assets/imgpost/diagram.png]]
ORG
  "$ORG_TO_MDX" org/posts/imgpost.org src/content/blog/imgpost.mdx
  [[ -f public/blog-assets/imgpost/diagram.png ]] \
    || fail_test "expected asset copied to public/blog-assets/imgpost/diagram.png"
  assert_contains "/blog-assets/imgpost/diagram.png" src/content/blog/imgpost.mdx
  assert_not_contains "../assets/imgpost" src/content/blog/imgpost.mdx
}

test_tags_lowercased_and_split() {
  cat > org/posts/t.org <<'ORG'
#+TITLE: Tags
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01
#+TAGS: Foo, BAR baz

Body.
ORG
  "$ORG_TO_MDX" org/posts/t.org src/content/blog/t.mdx
  assert_contains "- 'foo'" src/content/blog/t.mdx
  assert_contains "- 'bar'" src/content/blog/t.mdx
  assert_contains "- 'baz'" src/content/blog/t.mdx
  assert_not_contains "Foo" src/content/blog/t.mdx
}

test_frontmatter_canonical_keys_present() {
  write_minimal_post org/posts/p.org
  "$ORG_TO_MDX" org/posts/p.org src/content/blog/p.mdx
  assert_contains "title: 'Sample'" src/content/blog/p.mdx
  assert_contains "pubDate: '2026-01-01'" src/content/blog/p.mdx
  assert_contains "draft: false" src/content/blog/p.mdx
  assert_contains "Generated from org/posts/p.org" src/content/blog/p.mdx
}

test_draft_flag_propagates() {
  cat > org/posts/p.org <<'ORG'
#+TITLE: Draft
#+DESCRIPTION: A description that is comfortably within the twenty to two hundred character bounds.
#+DATE: 2026-01-01
#+DRAFT: t

Body.
ORG
  "$ORG_TO_MDX" org/posts/p.org src/content/blog/p.mdx
  assert_contains "draft: true" src/content/blog/p.mdx
}

# -- Driver --

run_test test_missing_title_fails
run_test test_missing_description_fails
run_test test_missing_date_fails
run_test test_math_detected_paren
run_test test_math_detected_bracket
run_test test_math_false_when_absent
run_test test_hasdemos_false_for_callout_only_mdx_block
run_test test_hasdemos_true_for_client_directive
run_test test_heading_shift_plus_one
run_test test_assets_copied_and_links_rewritten
run_test test_tags_lowercased_and_split
run_test test_frontmatter_canonical_keys_present
run_test test_draft_flag_propagates

echo
echo "$pass passed, $fail failed"
if [[ $fail -gt 0 ]]; then
  printf '  - %s\n' "${failed_names[@]}" >&2
  exit 1
fi
