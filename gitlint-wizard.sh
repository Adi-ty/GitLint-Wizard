#!/bin/bash

CONFIG_FILE=".gitlintwizardrc"
HOOK_FILE=".git/hooks/prepare-commit-msg"
VERSION_FILE="VERSION"

# Default configuration
DEFAULT_CONFIG=(
  "# Allowed commit types (comma-separated)"
  "TYPES=feat,fix,chore,docs,style,refactor,test"
  "# Max subject length"
  "MAX_LENGTH=50"
  "# Require JIRA ticket? (true/false)"
  "REQUIRE_JIRA=false"
  "# Emoji support (true/false)"
  "USE_EMOJI=true"
  "# Auto-versioning (true/false)"
  "AUTO_VERSION=true"
)

install() {
  cp "$0" "$HOOK_FILE" && chmod +x "$HOOK_FILE"
  if [ ! -f "$CONFIG_FILE" ]; then
    printf "%s\n" "${DEFAULT_CONFIG[@]}" >"$CONFIG_FILE"
  fi
  [ ! -f "$VERSION_FILE" ] && echo "0.1.0" >"$VERSION_FILE"
  echo "GitLint Wizard installed! Configuration: $CONFIG_FILE"
}

uninstall() {
  rm -f "$HOOK_FILE" && echo "GitLint Wizard removed!"
}

validate_commit() {
  local msg=$1
  local type_regex='^[a-z]+(\([a-z-]+\))?!?: .+'

  # Load configuration
  source "$CONFIG_FILE" 2>/dev/null

  # Split commit message
  IFS=': ' read -r type scope <<<"$msg"

  # Validate format
  [[ ! "$msg" =~ $type_regex ]] && return 1

  # Check allowed types
  local allowed_types="${TYPES//,/|}"
  [[ ! "$type" =~ ($allowed_types) ]] && return 2

  # Check subject length
  local subject=$(echo "$msg" | cut -d: -f2- | xargs)
  [ ${#subject} -gt "$MAX_LENGTH" ] && return 3

  # JIRA ticket check
  if [ "$REQUIRE_JIRA" = true ] && [[ ! "$msg" =~ [A-Z]+-[0-9]+ ]]; then
    return 4
  fi

  return 0
}

bump_version() {
  [ "$AUTO_VERSION" != "true" ] && return

  local current_version=$(cat "$VERSION_FILE")
  IFS='.' read -r major minor patch <<<"${current_version//[!0-9]/ }"

  case "$1" in
  feat) minor=$((minor + 1)) ;;
  fix) patch=$((patch + 1)) ;;
  *) return ;;
  esac

  new_version="$major.$minor.$patch"
  echo "$new_version" >"$VERSION_FILE"
  echo "Version bumped to $new_version!"
}

add_emoji() {
  [ "$USE_EMOJI" != "true" ] && echo "$1" && return

  declare -A emoji_map=(
    [feat]="✨" [fix]="🐛" [docs]="📚"
    [style]="💄" [refactor]="♻️" [test]="✅"
  )

  local type=$(echo "$1" | cut -d: -f1)
  echo "${emoji_map[$type]} $1"
}

commit_hook() {
  [ -z "$2" ] && exit 0 # Skip for merge commits

  if [[ "$2" == "message" ]]; then
    msg=$(cat "$1")
  else
    msg=$(echo "$@" | sed -n "s/.*'-m' '\([^']*\).*/\1/p")
  fi

  validate_commit "$msg"
  case $? in
  1) echo "Invalid format! Use: type(scope): description" >&2 ;;
  2) echo "Invalid type! Allowed: ${TYPES}" >&2 ;;
  3) echo "Subject too long! Max ${MAX_LENGTH} chars" >&2 ;;
  4) echo "Missing JIRA ticket!" >&2 ;;
  0)
    bump_version "$(echo "$msg" | cut -d: -f1)"
    new_msg=$(add_emoji "$msg")
    echo "$new_msg" >"$1"
    exit 0
    ;;
  esac
  exit 1
}

check_ai_dependencies() {
  if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for AI features. Install with 'brew install jq' or 'apt-get install jq'"
    exit 1
  fi
}

ai_generate_commit() {
  local diff_content=$1
  local api_key=$2
  local prompt="Generate a Conventional Commit message based on this diff:\n\n${diff_content}\n\n\
Follow these rules: ${TYPES}, max ${MAX_LENGTH} chars. \
Format: type(scope): message. No markdown. Current version: $(cat $VERSION_FILE)"
  
  local json_payload=$(jq -n \
    --arg prompt "$prompt" \
    '{
      "contents": [{
        "parts": [{
          "text": $prompt
        }]
      }],
      "generationConfig": {
        "temperature": 0.2,
        "candidateCount": 1
      }
    }')

  local response=$(echo "$json_payload" | curl -s -X POST \
      -H "Content-Type: application/json" \
      -d @- \
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent?key=$api_key")

  echo "$response" | jq -r '.candidates[0].content.parts[0].text' | \
    sed -e 's/^```\(.*\)$/\1/' -e 's/^```$//' | \
    grep -v '^$' | head -n 1 | \
    sed 's/^\s*//;s/\s*$//'
}

ai_commit() {
  check_ai_dependencies
  source "$CONFIG_FILE" 2>/dev/null
  
  if [ -z "$GEMINI_API_KEY" ]; then
    echo "Error: Add GEMINI_API_KEY to your .gitlintwizardrc"
    exit 1
  fi

  local diff=$(git diff --cached)
  [ -z "$diff" ] && diff=$(git diff HEAD~1)
  
  echo "🤖 Analyzing code changes..."
  local ai_msg=$(ai_generate_commit "$diff" "$GEMINI_API_KEY")

  validate_commit "$ai_msg"
  if [ $? -ne 0 ]; then
    echo "AI generated invalid message: $ai_msg" >&2
    exit 1
  fi
  
  read -p "Use this commit message? '$ai_msg' [Y/n] " yn
  case $yn in
    [Nn]*) echo "Commit aborted" && exit 0;;
    *) git commit -m "$ai_msg";;
  esac
}

case "$1" in
install) install ;;
uninstall) uninstall ;;
ai-commit) ai_commit ;;
*) commit_hook "$@" ;;
esac