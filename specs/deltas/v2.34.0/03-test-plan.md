# Auto-Generated Test Plan — Antigravity v2.34.0

## Verification Gates
1. `python3 scripts/sync-antigravity-docs.py --self-test`
2. `python3 verification/verify_compat_guardrails.py`
3. `python3 verification/verify-live-rpc-flow.py`
4. `python3 verification/verify-v233-capabilities.py`
5. `python3 verification/verify-compat-matrix.py`
6. `python3 verification/esdd-verify.py`
7. GitHub Actions `macos-15` `swift test` + `xcodebuild` + `XCUITest` (`macos-xcode-verify.yml`)
