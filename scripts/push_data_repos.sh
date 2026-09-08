#!/usr/bin/env bash
# Push Nketa JSON data to separate GitHub repos on ezeanyimhenry1.
#
# Prerequisite: create EMPTY public repos on GitHub (no README):
#   - igbo-events
#   - igbo-proverbs
#   - igbo-history
#   - igbo-cosmology
#   igbonsibidi-names
#
# Create at: https://github.com/new?name=REPO_NAME

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DATA="$ROOT/assets/data"
WORK="$ROOT/scripts/.github_data_repos"
SSH_HOST="${GITHUB_SSH_HOST:-github-ezeanyimhenry1}"
GITHUB_USER="${GITHUB_USER:-ezeanyimhenry1}"

declare -a REPOS=(
  "igbo-events:events.json"
  "igbo-proverbs:proverbs.json"
  "igbo-cosmology:igbo_cosmology.json"
  "igbonsibidi-names:dictionary.json"
)

prepare_repo() {
  local repo="$1"
  shift
  local dir="$WORK/$repo"
  rm -rf "$dir"
  mkdir -p "$dir"
  for file in "$@"; do
    cp "$DATA/$file" "$dir/$file"
  done
  cat > "$dir/README.md" <<EOF
# $repo

JSON data source for the Nketa Igbo culture app.
EOF
  git -C "$dir" init -b main >/dev/null
  git -C "$dir" add .
  git -C "$dir" commit -m "Restore content data for Nketa app" >/dev/null
  git -C "$dir" remote remove origin 2>/dev/null || true
  git -C "$dir" remote add origin "git@${SSH_HOST}:${GITHUB_USER}/${repo}.git"
}

push_repo() {
  local repo="$1"
  local dir="$WORK/$repo"
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" "https://github.com/${GITHUB_USER}/${repo}")"
  if [[ "$code" != "200" ]]; then
    echo "SKIP ${repo}: GitHub repo not found (HTTP ${code})."
    echo "  Create empty repo: https://github.com/new?name=${repo}"
    return 1
  fi
  git -C "$dir" push -u origin main
  echo "Pushed ${repo}"
}

mkdir -p "$WORK"

for entry in "${REPOS[@]}"; do
  repo="${entry%%:*}"
  files="${entry#*:}"
  IFS=',' read -r -a file_list <<< "$files"
  prepare_repo "$repo" "${file_list[@]}"
  push_repo "$repo" || true
done

prepare_repo "igbo-history" "timeline.json" "stories.json"
push_repo "igbo-history" || true

echo "Done. Local mirrors are in ${WORK}"
