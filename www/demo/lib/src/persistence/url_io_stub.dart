/// Stub implementation of URL I/O for non-web targets (VM / flutter test).
///
/// All operations are no-ops so the test suite can import [url_state.dart]
/// without `package:web` being available.
library;

/// Returns an empty string — no URL is accessible in a VM environment.
String readRawHash() => '';

/// No-op — there is no browser history to update in a VM environment.
void writeRawHash(String encoded) {}
