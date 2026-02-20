#!/usr/bin/env bash
# verify-no-restrictions.sh - Checks that account/usage restrictions are properly removed
# Run after pulling from upstream to detect if restrictions were re-introduced
#
# Usage: bash scripts/verify-no-restrictions.sh
# Exit code 0 = all patches intact, 1 = restrictions detected

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0
WARNINGS=0

check_file() {
  local file="$1"
  local pattern="$2"
  local description="$3"
  local should_exist="${4:-false}" # true = pattern SHOULD exist, false = pattern should NOT exist

  if [ ! -f "$file" ]; then
    echo -e "${RED}FAIL${NC}: File not found: $file"
    FAILED=$((FAILED + 1))
    return
  fi

  if [ "$should_exist" = "true" ]; then
    if grep -qE "$pattern" "$file"; then
      echo -e "${GREEN}OK${NC}: $description"
    else
      echo -e "${RED}FAIL${NC}: $description"
      echo "       Expected pattern '$pattern' in $file"
      FAILED=$((FAILED + 1))
    fi
  else
    # Exclude comment lines (// and #) when checking for unwanted patterns
    if grep -vE '^\s*(//|#)' "$file" | grep -qE "$pattern"; then
      echo -e "${RED}FAIL${NC}: $description"
      echo "       Found unwanted pattern '$pattern' in $file"
      FAILED=$((FAILED + 1))
    else
      echo -e "${GREEN}OK${NC}: $description"
    fi
  fi
}

echo ""
echo "========================================="
echo " OpenWhispr Fork - Restriction Verifier"
echo "========================================="
echo ""
echo "Checking that account/usage restrictions are removed..."
echo ""

# === useUsage.ts checks ===
echo "--- src/hooks/useUsage.ts ---"

# Should NOT have the original "return null when not signed in" behavior
check_file "src/hooks/useUsage.ts" \
  'if \(!isSignedIn\) return null' \
  "useUsage should NOT return null when not signed in" \
  false

# Should have the FORK PATCH unlimited return
check_file "src/hooks/useUsage.ts" \
  'FORK PATCH.*Never gate features' \
  "useUsage should have FORK PATCH for unlimited usage" \
  true

# Should NOT have 2000 as default limit
check_file "src/hooks/useUsage.ts" \
  'limit.*\?\? 2000' \
  "useUsage should NOT default limit to 2000" \
  false

# isOverLimit and isApproachingLimit should be hardcoded false
check_file "src/hooks/useUsage.ts" \
  'isOverLimit = false.*FORK PATCH' \
  "isOverLimit should be hardcoded false" \
  true

check_file "src/hooks/useUsage.ts" \
  'isApproachingLimit = false.*FORK PATCH' \
  "isApproachingLimit should be hardcoded false" \
  true

echo ""

# === useAudioRecording.js checks ===
echo "--- src/hooks/useAudioRecording.js ---"

check_file "src/hooks/useAudioRecording.js" \
  'notifyLimitReached' \
  "useAudioRecording should NOT call notifyLimitReached" \
  false

check_file "src/hooks/useAudioRecording.js" \
  'FORK PATCH.*Limit notifications disabled' \
  "useAudioRecording should have FORK PATCH comment" \
  true

echo ""

# === ipcHandlers.js checks ===
echo "--- src/helpers/ipcHandlers.js ---"

check_file "src/helpers/ipcHandlers.js" \
  'code: "LIMIT_REACHED"' \
  "ipcHandlers should NOT return LIMIT_REACHED error code" \
  false

check_file "src/helpers/ipcHandlers.js" \
  'FORK PATCH.*429' \
  "ipcHandlers should have FORK PATCH for 429 handling" \
  true

echo ""

# === ControlPanel.tsx checks ===
echo "--- src/components/ControlPanel.tsx ---"

check_file "src/components/ControlPanel.tsx" \
  'onLimitReached' \
  "ControlPanel should NOT listen for onLimitReached events" \
  false

check_file "src/components/ControlPanel.tsx" \
  'pastDueTitle.*pastDueDescription.*destructive' \
  "ControlPanel should NOT show past-due billing toast" \
  false

echo ""

# === UpgradePrompt.tsx checks ===
echo "--- src/components/UpgradePrompt.tsx ---"

check_file "src/components/UpgradePrompt.tsx" \
  'wordsUsed = 2000' \
  "UpgradePrompt should NOT default wordsUsed to 2000" \
  false

check_file "src/components/UpgradePrompt.tsx" \
  'limit = 2000' \
  "UpgradePrompt should NOT default limit to 2000" \
  false

echo ""

# === main.jsx checks ===
echo "--- src/main.jsx ---"

check_file "src/main.jsx" \
  'setNeedsReauth\(true\)' \
  "main.jsx should NOT force re-authentication" \
  false

check_file "src/main.jsx" \
  'FORK PATCH.*Re-authentication gate removed' \
  "main.jsx should have FORK PATCH for re-auth removal" \
  true

echo ""

# === Summary ===
echo "========================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}ALL CHECKS PASSED${NC} - No restrictions detected"
  echo "========================================="
  exit 0
else
  echo -e "${RED}$FAILED CHECK(S) FAILED${NC} - Restrictions may have been re-introduced"
  echo ""
  echo -e "${YELLOW}To fix:${NC}"
  echo "  1. Review the failed checks above"
  echo "  2. Look for 'FORK PATCH' comments in the codebase to see expected patterns"
  echo "  3. See CLAUDE.md section 'Fork Customizations' for full documentation"
  echo "  4. Ask Claude Code to re-apply the restriction removal patches"
  echo "========================================="
  exit 1
fi
