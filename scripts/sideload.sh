#!/usr/bin/env bash
# Sideload helper — temporarily patches project.yml + entitlements so
# a free-tier Apple ID can sign + run Mealgram on a personal iPhone.
#
# Usage:
#   ./scripts/sideload.sh prep ABCDE12345 [optional-bundle-suffix]
#   ./scripts/sideload.sh revert
#
# After `prep`: open Mealgram.xcodeproj, attach iPhone, hit Run.
# After you're done: `./scripts/sideload.sh revert` puts everything back.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT"

cmd="${1:-help}"

case "$cmd" in
  prep)
    team="${2:-}"
    suffix="${3:-personal}"
    if [[ -z "$team" ]]; then
      echo "✗ Missing team ID. Get it from Xcode → Settings → Accounts → your Apple ID → Team."
      echo ""
      echo "Usage: ./scripts/sideload.sh prep <TEAM_ID> [bundle-suffix]"
      echo "Example: ./scripts/sideload.sh prep ABCDE12345 mybuild"
      exit 1
    fi

    if ! git diff --quiet project.yml Mealgram/Supporting/Mealgram.entitlements 2>/dev/null; then
      echo "✗ project.yml or entitlements already has uncommitted changes."
      echo "  Either commit/stash them or run: ./scripts/sideload.sh revert"
      exit 1
    fi

    echo "→ Patching project.yml..."
    # Set DEVELOPMENT_TEAM
    /usr/bin/sed -i.bak "s|DEVELOPMENT_TEAM: \"\"|DEVELOPMENT_TEAM: \"$team\"|" project.yml

    # Bump Bundle IDs with suffix so free-tier can issue profile
    /usr/bin/sed -i.bak2 \
      -e "s|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios$|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.$suffix|" \
      -e "s|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.widget|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.$suffix.widget|" \
      -e "s|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.tests|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.$suffix.tests|" \
      -e "s|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.uitests|PRODUCT_BUNDLE_IDENTIFIER: app.mealgram.ios.$suffix.uitests|" \
      project.yml

    # Free tier can't issue Sign in with Apple or HealthKit entitlements.
    # Replace the live entitlements with a free-tier-compatible variant.
    echo "→ Patching entitlements..."
    cat > Mealgram/Supporting/Mealgram.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/propertylist-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
EOF

    # Capabilities in project.yml also need to drop applesignin/healthkit
    # so xcodegen doesn't re-inject them.
    /usr/bin/sed -i.bak3 \
      -e '/com\.apple\.developer\.applesignin:/,/^$/d' \
      -e '/com\.apple\.developer\.healthkit:/,/healthkit\.access:/d' \
      project.yml

    rm -f project.yml.bak project.yml.bak2 project.yml.bak3

    echo "→ Regenerating Xcode project..."
    make generate >/dev/null 2>&1

    cat <<EOM

✓ Sideload-ready.

Bundle ID is now: app.mealgram.ios.$suffix
Team ID is now:   $team
Sign in with Apple + HealthKit: disabled (free tier limitation)
Widget bundle ID: app.mealgram.ios.$suffix.widget

Next steps:
  1. Open Mealgram.xcodeproj in Xcode
  2. Connect iPhone via USB (trust the Mac if prompted)
  3. Select iPhone as run destination (top bar dropdown)
  4. Edit → Scheme → Run → Arguments → add: -mealgramDebugBypassAuth
     (this skips the Sign in screen — required since SIWA is off)
  5. ⌘R to build + install + run
  6. On iPhone: Settings → General → VPN & Device Management → trust profile

When done testing, revert with:
  ./scripts/sideload.sh revert

EOM
    ;;

  revert)
    echo "→ Reverting project.yml + entitlements to committed state..."
    git checkout -- project.yml Mealgram/Supporting/Mealgram.entitlements
    echo "→ Regenerating Xcode project..."
    make generate >/dev/null 2>&1
    echo "✓ Back to prod-ready state."
    ;;

  *)
    cat <<EOM
Sideload helper for free-tier Apple ID testing on a real iPhone.

Commands:
  prep <TEAM_ID> [suffix]  Patch project.yml + entitlements for sideload
  revert                   Reset everything to committed prod state

Examples:
  ./scripts/sideload.sh prep ABCDE12345
  ./scripts/sideload.sh prep ABCDE12345 mybuild
  ./scripts/sideload.sh revert

Get your TEAM_ID from Xcode → Settings → Accounts → your Apple ID.
EOM
    ;;
esac
