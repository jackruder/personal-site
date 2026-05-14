#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <input.org> <output.mdx>" >&2
  exit 1
fi

input="$1"
output="$2"
slug="$(basename "$input" .org)"
rel_input="${input#./}"
out_dir="$(dirname "$output")"
tmp_output="$output.tmp"
cleaned_output="$output.cleaned"
trap 'rm -f "$tmp_output" "$cleaned_output"' EXIT

TITLE=''
DESCRIPTION=''
DATE=''
UPDATED=''
TAGS=''
DRAFT=''
OG_IMAGE=''

while IFS= read -r line; do
  if [[ $line =~ ^#\+([A-Z_]+):[[:space:]]*(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "$key" in
      TITLE) TITLE="$value" ;;
      DESCRIPTION) DESCRIPTION="$value" ;;
      DATE) DATE="$value" ;;
      UPDATED) UPDATED="$value" ;;
      TAGS) TAGS="$value" ;;
      DRAFT) DRAFT="$value" ;;
      OG_IMAGE) OG_IMAGE="$value" ;;
    esac
  fi
done < "$input"

[[ -n "$TITLE" ]] || { echo "error: missing required keyword #+TITLE in $input" >&2; exit 1; }
[[ -n "$DESCRIPTION" ]] || { echo "error: missing required keyword #+DESCRIPTION in $input" >&2; exit 1; }
[[ -n "$DATE" ]] || { echo "error: missing required keyword #+DATE in $input" >&2; exit 1; }

math=false
if grep -Eq '\\\(|\\\[|\$\$' "$input"; then
  math=true
fi

has_demos=false
if grep -Eiq '^#\+BEGIN_EXPORT[[:space:]]+mdx' "$input"; then
  has_demos=true
fi

draft=false
if [[ "${DRAFT,,}" == 't' || "${DRAFT,,}" == 'true' ]]; then
  draft=true
fi

asset_src="org/assets/$slug"
asset_dest="public/blog-assets/$slug"
if [[ -d "$asset_src" ]]; then
  mkdir -p "$asset_dest"
  find "$asset_dest" -mindepth 1 ! -name '.gitkeep' -delete
  cp -R "$asset_src"/. "$asset_dest"/
fi

mkdir -p "$out_dir"
pandoc "$input" \
  --from org \
  --to gfm+yaml_metadata_block+footnotes+tex_math_dollars+raw_attribute \
  --wrap=preserve \
  --shift-heading-level-by=-1 \
  -o "$tmp_output"

sed -i "s#\.\./assets/$slug/#/blog-assets/$slug/#g" "$tmp_output"

python - "$tmp_output" "$cleaned_output" <<'PYTHON'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8')
lines = source.splitlines()
index = 0
imports = []
seen_imports = set()

if lines[:1] == ['---']:
    index = 1
    while index < len(lines) and lines[index] != '---':
        index += 1
    if index < len(lines):
        index += 1

result = []
while index < len(lines):
    line = lines[index]
    if line == '```{=org}':
        index += 1
        while index < len(lines) and lines[index] != '```':
            index += 1
        index += 1
        continue
    if line == '```{=mdx}':
        index += 1
        block = []
        while index < len(lines) and lines[index] != '```':
            block.append(lines[index])
            index += 1
        index += 1

        while block and block[0].startswith('import '):
            statement = block.pop(0)
            if statement not in seen_imports:
                imports.append(statement)
                seen_imports.add(statement)
        while block and block[0] == '':
            block.pop(0)
        if block:
            result.extend(block)
            result.append('')
        continue
    result.append(line)
    index += 1

if imports:
    result = imports + [''] + result

cleaned = '\n'.join(result).strip() + '\n'
Path(sys.argv[2]).write_text(cleaned, encoding='utf-8')
PYTHON

yaml_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/''/g")"
}

write_tags() {
  if [[ -z "$1" ]]; then
    printf 'tags: []\n'
    return
  fi

  local normalized
  normalized="$(printf '%s' "$1" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')"
  local tags=()
  local tag
  for tag in $normalized; do
    tags+=("$tag")
  done

  if [[ ${#tags[@]} -eq 0 ]]; then
    printf 'tags: []\n'
    return
  fi

  printf 'tags:\n'
  for tag in "${tags[@]}"; do
    printf '  - %s\n' "$(yaml_quote "$tag")"
  done
}

{
  printf -- '---\n'
  printf 'title: %s\n' "$(yaml_quote "$TITLE")"
  printf 'description: %s\n' "$(yaml_quote "$DESCRIPTION")"
  printf 'pubDate: %s\n' "$(yaml_quote "$DATE")"
  if [[ -n "$UPDATED" ]]; then
    printf 'updatedDate: %s\n' "$(yaml_quote "$UPDATED")"
  fi
  write_tags "$TAGS"
  printf 'draft: %s\n' "$draft"
  printf 'math: %s\n' "$math"
  printf 'hasDemos: %s\n' "$has_demos"
  if [[ -n "$OG_IMAGE" ]]; then
    printf 'ogImage: %s\n' "$(yaml_quote "$OG_IMAGE")"
  fi
  printf -- '---\n'
  printf '{/* Generated from %s. Do not edit. */}\n\n' "$rel_input"
  cat "$cleaned_output"
} > "$output"

echo "converted: $input -> $output"
