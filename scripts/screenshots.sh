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

# --- App Store Connect size normalisation -----------------------------------
#
# App Store Connect only accepts a fixed list of iPhone screenshot pixel sizes.
# Simulator captures come out at the device's *native* size (iPhone 16 =
# 1179 × 2556, iPhone 16 Pro Max = 1320 × 2868), neither of which is on that
# list — so a raw upload gets rejected. We normalise every PNG under
# ./screenshots/ to the 6.5" portrait slot, 1242 × 2688: the accepted size
# closest to the capture (near-identical ~0.46 aspect ratio, smallest rescale).
#
# Cover-scale + centre-crop, so nothing is stretched — at most a couple of
# pixels are shaved off the top/bottom. Landscape captures (none today, but
# just in case) map to the 2688 × 1242 slot. Uses macOS's built-in `sips`, so
# no extra dependency. Idempotent: an already-1242 × 2688 image is left as-is.
APPSTORE_PORTRAIT_W=1242
APPSTORE_PORTRAIT_H=2688

normalize_appstore_sizes() {
  command -v sips >/dev/null 2>&1 || { err "sips not found (ships with macOS) — can't resize screenshots."; return 1; }

  local count=0 skipped=0
  while IFS= read -r -d '' png; do
    local w h tw th
    w=$(sips -g pixelWidth  "$png" | awk '/pixelWidth/  {print $2}')
    h=$(sips -g pixelHeight "$png" | awk '/pixelHeight/ {print $2}')
    [ -n "$w" ] && [ -n "$h" ] || { err "  ! couldn't read pixel size of $png — skipping."; continue; }

    # Match the App Store slot's orientation to the capture's.
    if [ "$h" -ge "$w" ]; then tw=$APPSTORE_PORTRAIT_W; th=$APPSTORE_PORTRAIT_H
    else                       tw=$APPSTORE_PORTRAIT_H; th=$APPSTORE_PORTRAIT_W; fi

    if [ "$w" = "$tw" ] && [ "$h" = "$th" ]; then skipped=$((skipped + 1)); continue; fi

    # Cover-scale: resample on whichever axis leaves the *other* axis >= target
    # (height-after-width-resample = h·tw/w  ⇒  compare h·tw vs th·w), then
    # centre-crop to the exact target. sips -c takes <height> <width>.
    if [ "$(( h * tw ))" -ge "$(( th * w ))" ]; then
      sips --resampleWidth  "$tw" "$png" >/dev/null
    else
      sips --resampleHeight "$th" "$png" >/dev/null
    fi
    sips -c "$th" "$tw" "$png" >/dev/null
    count=$((count + 1))
  done < <(find screenshots -type f -name '*.png' -print0)

  local note=""
  [ "$skipped" -gt 0 ] && note=" ($skipped already correct)"
  info "Resized $count screenshot(s) to ${APPSTORE_PORTRAIT_W}×${APPSTORE_PORTRAIT_H} for App Store Connect${note}."
}

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
  DEVICES=()
  while IFS= read -r line; do
    [ -n "$line" ] && DEVICES+=("$line")
  done < <(xcrun simctl list devices available \
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

info "Captured. Screenshots are in ./screenshots/ — open ./screenshots/screenshots.html to review."

# --- 5. Transparent widget cutouts (optional, re-runnable) ------------------
#
# The widget-gallery screens are shot against a chroma-key green backdrop
# (a screen capture has no alpha channel). scripts/remove_widget_backgrounds.py
# keys that out into per-widget transparent PNGs under ./screenshots-widgets/.
# It's fully standalone — re-run it any time without re-shooting.

# EXTRACT_WIDGETS=1 / =0 skips the prompt (1 = yes, 0 = no). Default: ask.
extract="${EXTRACT_WIDGETS:-}"
if [ -z "$extract" ]; then
  printf "\033[36mExtract transparent widget PNGs now? [Y/n] \033[0m"
  read -r reply || reply="n"
  case "$reply" in [Nn]*) extract=0 ;; *) extract=1 ;; esac
fi

if [ "$extract" = "1" ]; then
  python3 scripts/remove_widget_backgrounds.py
else
  info "Skipped widget extraction. Run later: python3 scripts/remove_widget_backgrounds.py"
fi

# --- 6. Normalise to an App Store Connect pixel size ------------------------
#
# Last, so the steps above (and any later standalone widget extraction) work on
# the native-resolution captures. This rewrites ./screenshots/ in place to the
# accepted 1242 × 2688 size. (screenshots-widgets/ is intentionally left alone —
# those transparent cutouts are widget-sized source art, not upload candidates.)

normalize_appstore_sizes

info "Done. ./screenshots/ is ready to drag into App Store Connect."
