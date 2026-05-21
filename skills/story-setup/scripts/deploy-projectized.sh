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
codex_template_dir="$story_setup_dir/references/templates/codex"

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

if [[ ! -d "$codex_template_dir/agents" || ! -f "$codex_template_dir/config.toml.tmpl" ]]; then
  echo "Missing Codex templates under: $codex_template_dir" >&2
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

merge_codex_config() {
  local config_file="$1"
  local config_template="$2"
  local merged="$tmp_dir/codex.config.toml"

  if [[ ! -f "$config_file" ]]; then
    cp "$config_template" "$config_file"
    return
  fi

  awk '
    BEGIN {
      in_agents = 0
      has_agents = 0
      has_max_threads = 0
      has_max_depth = 0
      inserted = 0
    }

    function insert_missing() {
      if (in_agents && !inserted) {
        if (!has_max_threads) print "max_threads = 4"
        if (!has_max_depth) print "max_depth = 1"
        inserted = 1
      }
    }

    /^[[:space:]]*\[agents\][[:space:]]*$/ {
      if (in_agents) insert_missing()
      in_agents = 1
      has_agents = 1
      has_max_threads = 0
      has_max_depth = 0
      inserted = 0
      print
      next
    }

    /^[[:space:]]*\[/ {
      if (in_agents) {
        insert_missing()
        in_agents = 0
      }
      print
      next
    }

    in_agents && /^[[:space:]]*max_threads[[:space:]]*=/ {
      has_max_threads = 1
      print
      next
    }

    in_agents && /^[[:space:]]*max_depth[[:space:]]*=/ {
      has_max_depth = 1
      print
      next
    }

    { print }

    END {
      if (in_agents) insert_missing()
      if (!has_agents) {
        print ""
        print "# OH-STORY-CODEX Codex subagent defaults"
        print "[agents]"
        print "max_threads = 4"
        print "max_depth = 1"
      }
    }
  ' "$config_file" > "$merged"

  mv "$merged" "$config_file"
}

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

codex_dir="$project_dir/.codex"
codex_agents_dir="$codex_dir/agents"
mkdir -p "$codex_agents_dir"

for codex_agent_template in "$codex_template_dir"/agents/*.toml; do
  [[ -e "$codex_agent_template" ]] || continue
  cp "$codex_agent_template" "$codex_agents_dir/$(basename "$codex_agent_template")"
done

merge_codex_config "$codex_dir/config.toml" "$codex_template_dir/config.toml.tmpl"

echo "Deployed local skill package: $target_skill_dir"
echo "Updated agent rules: $agents_file"
echo "Updated Codex agents: $codex_agents_dir"
