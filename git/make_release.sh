#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# 1. Run tests (you can change this command as needed)
echo "🔍 Running tests..."
if ! pytest; then
  echo "❌ Tests failed. Aborting release."
  exit 1
fi

# 2. Fetch latest tag
echo "📦 Fetching latest tag..."
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")

echo "🔖 Latest tag: $latest_tag"

# 3. Increment version (patch)
IFS='.' read -ra parts <<< "${latest_tag#v}"
major="${parts[0]}"
minor="${parts[1]}"
patch="${parts[2]}"
new_patch=$((patch + 1))
new_tag="v$major.$minor.$new_patch"

# 4. Create new tag and push
echo "🚀 Creating new release tag: $new_tag"
git tag "$new_tag"
git push origin "$new_tag"

echo "✅ Release $new_tag created and pushed!"
