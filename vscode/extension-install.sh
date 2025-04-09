#!/usr/bin/env bash

set -euo pipefail

EXT_FILE="extensions.txt"
EXT_URL="https://raw.githubusercontent.com/radiant-ai-hub/docker-genai/main/vscode/extensions.txt"

# Download if missing
if [ ! -f "$EXT_FILE" ]; then
  curl -fsSL "$EXT_URL" -o "$EXT_FILE"
fi

# Install extensions, skipping comments and empty lines
while IFS= read -r extension; do
  [[ -z "$extension" || "$extension" =~ ^# ]] && continue
  export NODE_OPTIONS=--force-node-api-uncaught-exceptions-policy=true
  code --install-extension "$extension" --force 2> >(grep -v -i 'deprecationwarning\|trace-deprecation' >&2)
done < "$EXT_FILE"
