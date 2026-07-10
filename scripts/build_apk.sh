#!/bin/bash
set -e

# Auto-bumps the patch version + build number in pubspec.yaml, syncs
# lib/constants/version.dart, builds the debug APK, and renames the
# output to catchify-v<version>.apk.
#
# Usage: bash scripts/build_apk.sh [flavor]
#   flavor defaults to "github" (use "fdroid" for the F-Droid flavor)

cd "$(dirname "$0")/.."

PUBSPEC="pubspec.yaml"
FLAVOR="${1:-github}"

current=$(grep -oE '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$PUBSPEC" | sed 's/^version: //')
version="${current%+*}"
build="${current##*+}"

major=$(echo "$version" | cut -d. -f1)
minor=$(echo "$version" | cut -d. -f2)
patch=$(echo "$version" | cut -d. -f3)

new_patch=$((patch + 1))
new_build=$((build + 1))
new_version="${major}.${minor}.${new_patch}"

sed -i "s/^version: .*/version: ${new_version}+${new_build} # run update.sh after changing the version/" "$PUBSPEC"

bash update.sh

echo "Building catchify v${new_version}+${new_build} (flavor: ${FLAVOR})..."
flutter build apk --release --flavor "$FLAVOR"

apk_src="build/app/outputs/flutter-apk/app-${FLAVOR}-release.apk"
apk_dest="build/app/outputs/flutter-apk/catchify-v${new_version}.apk"
cp "$apk_src" "$apk_dest"

echo "Built ${apk_dest}"
