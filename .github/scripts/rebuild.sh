#!/usr/bin/env bash
set -euo pipefail

# Rebuild script for babel/website
# Runs from website/ in the existing source tree (no clone).
# Installs deps, runs pre-build steps, builds the Docusaurus site.

# --- Node version ---
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -f "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
    nvm install 20
    nvm use 20
fi
echo "[INFO] Node: $(node --version)"

# --- Package manager: Yarn 4.6.0 (Berry) via corepack ---
corepack enable
corepack prepare yarn@4.6.0 --activate

CURRENT_DIR="$(pwd)"

# --- Install root workspace deps and run bootstrap:sponsors ---
# babel/website is a monorepo: root package.json has workspaces, website/ is a workspace.
# bootstrap:sponsors downloads sponsors data required by docusaurus.config.js.
# The staging repo preserves the full tree, so ../package.json should be present.
if [ -f "../package.json" ] && node -e "const p=require('../package.json'); process.exit(p.workspaces ? 0 : 1)" 2>/dev/null; then
    echo "[INFO] Monorepo root found at .., installing from root..."
    cd ..
    yarn install
    yarn bootstrap:sponsors
    cd "$CURRENT_DIR"
else
    echo "[INFO] No monorepo root found, cloning source for root-level setup..."
    TEMP_DIR="/tmp/babel-website-root-$$"
    git clone --depth 1 --branch main https://github.com/babel/website "$TEMP_DIR"
    cd "$TEMP_DIR"
    corepack prepare yarn@4.6.0 --activate
    yarn install
    yarn bootstrap:sponsors
    # Copy any root-level generated data files to the working tree root
    # bootstrap:sponsors generates data at website-level paths referenced by docusaurus.config.js
    if [ -d "$TEMP_DIR/website" ]; then
        # Copy generated files that docusaurus.config.js references (sponsors data)
        for f in "$TEMP_DIR/website"/*.json; do
            [ -f "$f" ] && cp "$f" "$CURRENT_DIR/" && echo "[INFO] Copied $(basename $f)"
        done
    fi
    rm -rf "$TEMP_DIR"
    cd "$CURRENT_DIR"
fi

# --- Install website dependencies ---
yarn install

# --- Build Docusaurus site ---
npx docusaurus build --out-dir build/babel

echo "[DONE] Build complete."
