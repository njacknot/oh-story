#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <project_dir> [oh_story_codex_root]" >&2
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

project_dir="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
story_setup_dir="$(cd "$script_dir/.." && pwd)"
default_source_root="$(cd "$story_setup_dir/../.." && pwd)"
source_root="${2:-$default_source_root}"
template="$story_setup_dir/references/templates/AGENTS.md.tmpl"

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 1
fi

if [[ ! -f "$source_root/skills/story/SKILL.md" ]]; then
  echo "Invalid oh-story-codex root: $source_root" >&2
  exit 1
fi

if [[ ! -f "$template" ]]; then
  echo "Missing AGENTS.md template: $template" >&2
  exit 1
fi

target_skill_dir="$project_dir/.oh-story-codex"
mkdir -p "$target_skill_dir"

if command -v rsync >/dev/null 2>&1; then
  rsync -a \
    --exclude '.git/' \
    --exclude '.DS_Store' \
    --exclude 'node_modules/' \
    --exclude '.oh-story-codex/' \
    "$source_root/" "$target_skill_dir/"
else
  # Fallback for minimal shells. This intentionally preserves existing extra files.
  (cd "$source_root" && tar --exclude='.git' --exclude='.DS_Store' --exclude='node_modules' --exclude='.oh-story-codex' -cf - .) \
    | (cd "$target_skill_dir" && tar -xf -)
fi

project_name="$(basename "$project_dir")"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
managed_block="$tmp_dir/AGENTS.oh-story-codex.md"
agents_file="$project_dir/AGENTS.md"

escape_sed() {
  printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}

escaped_project_name="$(escape_sed "$project_name")"
sed "s/{项目名}/$escaped_project_name/g; s/{书名}/$escaped_project_name/g" "$template" > "$managed_block"

if [[ -f "$agents_file" ]]; then
  if grep -q '<!-- OH-STORY-CODEX:BEGIN -->' "$agents_file" && grep -q '<!-- OH-STORY-CODEX:END -->' "$agents_file"; then
    awk -v replacement="$managed_block" '
      BEGIN {
        while ((getline line < replacement) > 0) {
          block = block line ORS
        }
      }
      index($0, "<!-- OH-STORY-CODEX:BEGIN -->") {
        printf "%s", block
        in_block = 1
        next
      }
      index($0, "<!-- OH-STORY-CODEX:END -->") {
        in_block = 0
        next
      }
      !in_block { print }
    ' "$agents_file" > "$tmp_dir/AGENTS.md"
    mv "$tmp_dir/AGENTS.md" "$agents_file"
  else
    {
      printf '\n\n'
      cat "$managed_block"
    } >> "$agents_file"
  fi
else
  cp "$managed_block" "$agents_file"
fi

echo "Deployed local skill package: $target_skill_dir"
echo "Updated agent rules: $agents_file"
