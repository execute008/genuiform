/// Web implementation of URL I/O using `package:web` + `dart:js_interop`.
///
/// Reads and writes the browser's `window.location.hash` via `history.replaceState`
/// so that back/forward navigation is not polluted on every keystroke.
library;

import 'package:web/web.dart' as web;

/// Returns the current URL hash value, stripping the leading `#`.
///
/// Returns an empty string when there is no hash.
String readRawHash() {
  final hash = web.window.location.hash;
  return hash.startsWith('#') ? hash.substring(1) : hash;
}

/// Updates the URL hash to [encoded] using `history.replaceState`.
///
/// Does not add a new browser-history entry.
void writeRawHash(String encoded) {
  web.window.history.replaceState(null, '', '#$encoded');
}
