#!/bin/bash
set -euo pipefail

# Generate changelog from conventional commits since last tag
# Groups commits by type: Features, Fixes, Chores, etc.
# Auto-linkifies PR references

VERSION="$1"
REPO="${2:-mixpanel/mixpanel-swift}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version> [repo]"
  echo "Example: $0 6.3.0 mixpanel/mixpanel-swift"
  exit 1
fi

# Find the last tag (without 'v' prefix)
LAST_TAG=$(git tag --sort=-version:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || echo "")

if [ -z "$LAST_TAG" ]; then
  echo "No previous tags found. Generating changelog from all commits." >&2
  COMMIT_RANGE="HEAD"
else
  echo "Last tag: $LAST_TAG" >&2
  COMMIT_RANGE="$LAST_TAG..HEAD"
fi

# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)

# Get commits in range
COMMITS=$(git log "$COMMIT_RANGE" --pretty=format:"%s|||%H" --no-merges)

# Initialize arrays for different types
declare -a FEATURES
declare -a FIXES
declare -a CHORES

# Parse commits and categorize by conventional commit type
while IFS='|||' read -r SUBJECT COMMIT_HASH; do
  # Skip empty lines
  [ -z "$SUBJECT" ] && continue

  # Skip release commits
  [[ "$SUBJECT" =~ ^release: ]] && continue

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
  elif [[ "$SUBJECT" =~ ^chore: ]]; then
    MSG="${SUBJECT#chore: }"
    if [ -n "$PR_NUM" ]; then
      CHORES+=("- $MSG ([#$PR_NUM](https://github.com/$REPO/pull/$PR_NUM))")
    else
      CHORES+=("- $MSG")
    fi
  fi
done <<< "$COMMITS"

# Generate changelog markdown
echo "## [$VERSION](https://github.com/$REPO/tree/$VERSION) ($CURRENT_DATE)"
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

# Chores
if [ ${#CHORES[@]} -gt 0 ]; then
  echo "### Chores"
  echo ""
  for chore in "${CHORES[@]}"; do
    echo "$chore"
  done
  echo ""
fi

# Full changelog link
if [ -n "$LAST_TAG" ]; then
  echo "[Full Changelog](https://github.com/$REPO/compare/$LAST_TAG...$VERSION)"
else
  echo "[Full Changelog](https://github.com/$REPO/commits/$VERSION)"
fi
echo ""
