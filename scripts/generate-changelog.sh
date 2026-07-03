#!/bin/bash
set -euo pipefail

# Generate changelog from conventional commits since last tag
# Groups commits by type: Features, Fixes, Chores
# Auto-linkifies PR references

VERSION="$1"
REPO="${2:-mixpanel/mixpanel-swift}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [repo]"
  echo "Example: $0 6.3.0 mixpanel/mixpanel-swift"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_JSON="$SCRIPT_DIR/../.github/modules.json"

# Extract tag prefix from modules.json
if [ ! -f "$MODULES_JSON" ]; then
  echo "ERROR: modules.json not found at $MODULES_JSON"
  exit 1
fi

TAG_PREFIX=$(jq -e -r '.analytics.tag_prefix' "$MODULES_JSON" 2>/dev/null || echo "INVALID")
if [ "$TAG_PREFIX" = "INVALID" ] || [ "$TAG_PREFIX" = "null" ]; then
  echo "ERROR: Could not read tag_prefix from modules.json"
  exit 1
fi

# Build tag glob pattern
if [ "$TAG_PREFIX" = "" ]; then
  TAG_GLOB="[0-9]*"
else
  TAG_GLOB="${TAG_PREFIX}*"
fi

# Find previous tag using pattern
PREVIOUS_TAG=$(git tag --sort=-version:refname --list "$TAG_GLOB" | head -1 || true)

if [ -z "$PREVIOUS_TAG" ]; then
  echo "No previous tags found. Generating changelog from all commits."
  COMMIT_RANGE="HEAD"
else
  echo "Last tag: $PREVIOUS_TAG"
  COMMIT_RANGE="${PREVIOUS_TAG}..HEAD"
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Build version tag
VERSION_TAG="${TAG_PREFIX}${VERSION}"

# Get commits in range
COMMITS=$(git log "$COMMIT_RANGE" --pretty=format:"%s" --no-merges)

# Initialize arrays for different types
declare -a FEATURES=()
declare -a FIXES=()

# Parse commits and categorize by conventional commit type
while IFS= read -r SUBJECT; do
  # Skip empty lines
  [ -z "$SUBJECT" ] && continue

  # Skip release commits
  [[ "$SUBJECT" =~ ^release: ]] && continue

  # Skip chore commits
  [[ "$SUBJECT" =~ ^chore: ]] && continue

  # Extract PR number if present (#123)
  PR_NUM=""
  if [[ "$SUBJECT" =~ \(#([0-9]+)\) ]]; then
    PR_NUM="${BASH_REMATCH[1]}"
  fi

  # Parse conventional commit format
  if [[ "$SUBJECT" =~ ^feat: ]]; then
    MSG="${SUBJECT#feat: }"
    if [ -n "$PR_NUM" ]; then
      FEATURES+=("- $MSG ([#$PR_NUM](https://github.com/$REPO/pull/$PR_NUM))")
    else
      FEATURES+=("- $MSG")
    fi
  elif [[ "$SUBJECT" =~ ^fix: ]]; then
    MSG="${SUBJECT#fix: }"
    if [ -n "$PR_NUM" ]; then
      FIXES+=("- $MSG ([#$PR_NUM](https://github.com/$REPO/pull/$PR_NUM))")
    else
      FIXES+=("- $MSG")
    fi
  fi
done <<< "$COMMITS"

# Generate changelog markdown
echo "## [${VERSION_TAG}](https://github.com/${REPO}/tree/${VERSION_TAG}) (${CURRENT_DATE})"
echo ""

# Features
if [ ${#FEATURES[@]} -gt 0 ]; then
  echo "### Features"
  echo ""
  for feature in "${FEATURES[@]}"; do
    echo "$feature"
  done
  echo ""
fi

# Fixes
if [ ${#FIXES[@]} -gt 0 ]; then
  echo "### Fixes"
  echo ""
  for fix in "${FIXES[@]}"; do
    echo "$fix"
  done
  echo ""
fi

# Full changelog link
if [ -n "$PREVIOUS_TAG" ]; then
  echo "[Full Changelog](https://github.com/${REPO}/compare/${PREVIOUS_TAG}...${VERSION_TAG})"
else
  echo "[Full Changelog](https://github.com/${REPO}/commits/${VERSION_TAG})"
fi
echo ""
