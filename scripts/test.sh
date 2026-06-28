#!/bin/bash
# Runs the full Swift Native test suite (unit + integration + e2e).
# Works without Xcode — uses the bundled SwiftNativeTesting framework.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build --product SwiftNativeTestSuite
exec .build/debug/SwiftNativeTestSuite
