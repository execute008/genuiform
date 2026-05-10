import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web/web.dart' as web;

import 'theme/app_theme.dart';
import 'app/workbench_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load Roboto Flex so the first paint has the real text theme metrics.
  await GoogleFonts.pendingFonts([GoogleFonts.robotoFlex()]);
  runApp(const GenUIFormApp());

  // Production-only Flutter web release-build workaround. After the first
  // paint the engine sometimes stops pumping frames in response to setState
  // / StreamBuilder rebuilds — async results (LLM stream tokens, mascot
  // SVGs) sit in the controller but never paint. Confirmed in production
  // by dispatching `window.dispatchEvent(new Event('resize'))` with no
  // actual size change: the deferred form rendered instantly. A
  // SchedulerBinding.scheduleFrame() heartbeat does NOT take the same code
  // path through the engine and was not enough; only the platform-metrics
  // path that resize triggers wakes the renderer reliably.
  //
  // So pump synthetic resize events for the first 15s — long enough to
  // cover cold-load LLM streaming and mascot fetches, then stops so the
  // rest of the session runs at zero overhead. Once the user interacts,
  // the engine stays warm on its own.
  var ticks = 0;
  Timer.periodic(const Duration(milliseconds: 200), (timer) {
    ticks++;
    if (ticks > 75) {
      timer.cancel();
      return;
    }
    web.window.dispatchEvent(web.Event('resize'));
  });
}

class GenUIFormApp extends StatelessWidget {
  const GenUIFormApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GenUIForm Workbench',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const WorkbenchShell(),
    );
  }
}
