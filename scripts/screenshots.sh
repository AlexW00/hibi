#!/usr/bin/env bash
#
# Generate localized App Store screenshots for Hibi.
#
#   ./scripts/screenshots.sh                 # pick a simulator interactively
#   DEVICE="iPhone 16 Pro Max" ./scripts/screenshots.sh   # skip the menu
#
# Captures the Day / Week / Month tabs in en-US, zh-Hans, zh-Hant, ja and ko
# (configured in fastlane/Snapfile) and writes them to ./screenshots/<locale>/.
#
# Re-run any time the UI changes. Runs on the iOS Simulator (demo mode is a
# Debug-only build, so no real calendar/location/network is touched).

set -euo pipefail
cd "$(dirname "$0")/.."

err() { printf "\033[31m%s\033[0m\n" "$*" >&2; }
info() { printf "\033[36m%s\033[0m\n" "$*"; }

# --- Preconditions ----------------------------------------------------------

command -v xcrun >/dev/null 2>&1 || { err "Xcode command-line tools required (xcrun not found)."; exit 1; }
command -v fastlane >/dev/null 2>&1 || { err "fastlane not found. Install with: brew install fastlane"; exit 1; }
command -v ruby >/dev/null 2>&1 || { err "ruby required (ships with macOS)."; exit 1; }

# --- 1. Make sure SnapshotHelper.swift is present (official copy) ------------

if [ ! -f "HibiUITests/SnapshotHelper.swift" ]; then
  info "Fetching fastlane's SnapshotHelper.swift…"
  tmp="$(mktemp -d)"
  ( cd "$tmp" && fastlane snapshot init >/dev/null 2>&1 || true )
  if   [ -f "$tmp/SnapshotHelper.swift" ];           then cp "$tmp/SnapshotHelper.swift" HibiUITests/SnapshotHelper.swift
  elif [ -f "$tmp/fastlane/SnapshotHelper.swift" ];  then cp "$tmp/fastlane/SnapshotHelper.swift" HibiUITests/SnapshotHelper.swift
  else err "Couldn't fetch SnapshotHelper.swift. Run 'fastlane snapshot init' and copy it into HibiUITests/."; exit 1
  fi
  rm -rf "$tmp"
fi

# --- 2. Ensure the UI-test target + scheme exist ----------------------------

info "Syncing the HibiUITests target + HibiScreenshots scheme…"
ruby scripts/setup_screenshots.rb

# --- 3. Choose a device -----------------------------------------------------

if [ -z "${DEVICE:-}" ]; then
  info "Available iPhone simulators:"
  mapfile -t DEVICES < <(xcrun simctl list devices available \
    | grep -oE 'iPhone[^(]*' | sed 's/[[:space:]]*$//' | sort -u)

  if [ "${#DEVICES[@]}" -eq 0 ]; then
    err "No iPhone simulators found. Add one in Xcode › Settings › Components, or set DEVICE=…"; exit 1
  fi

  PS3="Pick a simulator (number): "
  select choice in "${DEVICES[@]}"; do
    if [ -n "${choice:-}" ]; then DEVICE="$choice"; break; fi
  done
fi

info "Using device: $DEVICE"

# --- 4. Run snapshot --------------------------------------------------------

fastlane snapshot --devices "$DEVICE"

info "Done. Screenshots are in ./screenshots/ — open ./screenshots/screenshots.html to review."
