// SwiftNativeTestSuite — runs all unit, integration and end-to-end tests and
// exits non-zero on any failure. Build with coverage to measure line coverage:
//
//   swift build --product SwiftNativeTestSuite \
//     -Xswiftc -profile-generate -Xswiftc -profile-coverage-mapping
//   LLVM_PROFILE_FILE=cov.profraw .build/debug/SwiftNativeTestSuite

import SwiftNativeTesting

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

let runner = TestRunner()
for suite in unitTests() { runner.add(suite) }
for suite in builderTests() { runner.add(suite) }
for suite in integrationTests() { runner.add(suite) }
for suite in e2eTests() { runner.add(suite) }

let code = runner.run()
exit(code)
