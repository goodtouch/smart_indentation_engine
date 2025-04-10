#!/usr/bin/env bash
set -euo pipefail

# release_tag.sh
#
# SUMMARY
#
#   Creates a new Git tag for the current commit and pushes it to the remote
#   repository.
#
#   If the --delete option is provided, it will delete the specified tag
#   from both the local and remote repositories.
#   Use with caution as this operation is destructive.
#
# USAGE
#
#  $ scripts/release_tag.sh <version> [--delete]

version="${1:?must pass version as argument (e.g. 1.0.0)}"

if [ "${2:-}" == "--delete" ]; then
  mode="delete"
else
  mode="create"
fi

# Validate version format (should be semantic versioning)
if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$ ]]; then
  echo -e "\033[31merror:\033[0m version must follow semantic versioning format (e.g., 1.0.0, 2.1.0-beta.1)"
  exit 1
fi

tag="v${version}"


main() {
  if [[ "$mode" == "delete" ]]; then
    confirm_deletion
  fi

  # Check if tag exists locally
  if git rev-parse "${tag}" >/dev/null 2>&1; then
    case "$mode" in
      create)
        warn "local tag '${tag}' already exists"
        ;;
      delete)
        delete_local_tag
        ;;
    esac
  else
    case "$mode" in
      create)
        create_local_tag
        ;;
      delete)
        warn "local tag '${tag}' does not exist"
        ;;
    esac
  fi

  # Check if tag exists on remote
  if git ls-remote --tags origin | grep -q "refs/tags/${tag}$"; then
    case "$mode" in
      create)
        warn "remote tag '${tag}' already exists"
        ;;
      delete)
        delete_remote_tag
        ;;
    esac
  else
    case "$mode" in
      create)
        maybe_push_tag
        ;;
      delete)
        warn "remote tag '${tag}' does not exist"
        ;;
    esac
  fi

  case "$mode" in
    create)
      success "tag '${tag}' created"
      ;;
    delete)
      success "tag '${tag}' deleted"
      ;;
  esac
}

confirm_deletion() {
  echo "warning: this will delete tag '${tag}' both locally and from the remote repository"
  read -p "Are you sure you want to proceed? [y/N] " answer
  if ! [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
    error "operation canceled"
  fi
}

create_local_tag() {
  if git tag -a "${tag}" -m "Release ${tag}"; then
    success "local tag '${tag}' created"
  else
    error "failed to create local tag '${tag}'"
  fi
}

maybe_push_tag() {
  read -p "Do you want to push tag ${tag} to remote repository? [y/N] " answer
  if [[ "$answer" =~ ^[yY]([eE][sS])?$ ]]; then
    if git push origin "${tag}"; then
      success "tag '${tag}' pushed to remote repository"
    else
      error "failed to push tag '${tag}' to remote repository"
    fi
  else
    warn "tag '${tag}' not pushed. Use 'git push origin \"${tag}\"' to push it"
  fi
}

delete_local_tag() {
  if git tag -d "${tag}"; then
    success "local tag '${tag}' deleted"
  else
    error "failed to delete local tag '${tag}'"
  fi
}

delete_remote_tag() {
  if git push --delete origin "${tag}"; then
    echo "remote tag '${tag}' deleted"
  else
    echo "failed to delete remote tag '${tag}'"
    exit 1
  fi
}

success() {
  echo -e "\033[32msuccess: \033[0m$1"
}

warn() {
  echo -e "\033[33mwarning: \033[0m$1"
}

error() {
  echo -e "\033[31merror: \033[0m$1"
  exit 1
}

main
