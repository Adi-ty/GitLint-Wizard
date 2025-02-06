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

case "$1" in
install) install ;;
uninstall) uninstall ;;
*) commit_hook "$@" ;;
esac
