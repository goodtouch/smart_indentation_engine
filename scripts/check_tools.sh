#!/usr/bin/env bash
set -euo pipefail

# check_env.sh
#
# SUMMARY
#
#   Checks for required tools in PATH

# Define colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

# Default tool list if none provided
TOOLS=${@:-mix elixir iex}

echo "Checking required tools..."
success=true

# Check each tool
for tool in $TOOLS; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${RESET}  $tool found"
  else
    echo -e "  ${RED}✗${RESET}  $tool not found in PATH"
    success=false
  fi
done

# Summary
if $success; then
  echo -e "${GREEN}All required tools are available${RESET}"
  exit 0
else
  echo -e "${RED}Some required tools are missing${RESET}"
  exit 1
fi
