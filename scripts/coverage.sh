#!/bin/bash
# Measures line/region/function coverage of the Swift Native framework sources
# using llvm-cov (no Xcode required). Fails if line coverage drops below 80%.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFRAW="$(pwd)/.build/coverage.profraw"
PROFDATA="$(pwd)/.build/coverage.profdata"
BIN=.build/debug/SwiftNativeTestSuite

echo "→ Building instrumented test suite…"
swift build --product SwiftNativeTestSuite \
  -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping >/dev/null

echo "→ Running tests…"
LLVM_PROFILE_FILE="$PROFRAW" "$BIN" >/dev/null

xcrun llvm-profdata merge -sparse "$PROFRAW" -o "$PROFDATA"

echo ""
echo "Per-file coverage (framework sources):"
xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" 2>/dev/null \
  | awk 'NR<=2 || ($1 ~ /SwiftNativeCore|SwiftNativeAppKit|SwiftNativeTestRenderer/)'

echo ""
echo "Aggregate (framework sources only):"
SUMMARY=$(xcrun llvm-cov report "$BIN" -instr-profile="$PROFDATA" \
  Sources/SwiftNativeCore Sources/SwiftNativeAppKit Sources/SwiftNativeTestRenderer 2>/dev/null | tail -1)
echo "$SUMMARY"

LINE_PCT=$(echo "$SUMMARY" | awk '{gsub(/%/,"",$10); print $10}')
echo ""
echo "Line coverage: ${LINE_PCT}%"
THRESHOLD=80
if (( $(echo "$LINE_PCT < $THRESHOLD" | bc -l) )); then
  echo "✗ Below ${THRESHOLD}% threshold"
  exit 1
fi
echo "✓ Meets ${THRESHOLD}% threshold"
