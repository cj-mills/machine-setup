#!/usr/bin/env bash
# Install the VS Code extensions whenever this list changes. Additive: extensions
# installed by hand stay.
set -euo pipefail

extensions=(
  anthropic.claude-code
  mechatroner.rainbow-csv
  ms-azuretools.vscode-containers
  ms-python.debugpy
  ms-python.python
  ms-python.vscode-pylance
  ms-python.vscode-python-envs
  ms-vscode-remote.remote-containers
  ms-vscode.cmake-tools
  ms-vscode.cpp-devtools
  ms-vscode.cpptools
  ms-vscode.cpptools-extension-pack
  ms-vscode.cpptools-themes
  twxs.cmake
)

if ! command -v code >/dev/null 2>&1; then
  echo "VS Code is not installed; converge the system layer first (scripts/converge-system.sh)." >&2
  exit 1
fi
for extension in "${extensions[@]}"; do
  code --install-extension "$extension" --force
done
