import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'app/workbench_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Roboto Flex backs the entire MaterialApp text theme. Letting Flutter web
  // fetch it lazily on first paint causes the frame to render with a fallback
  // font and never get a follow-up frame after the swap — the page looks
  // frozen until a window resize forces relayout. Awaiting the font load here
  // guarantees the first frame paints with the real typography.
  await GoogleFonts.pendingFonts([GoogleFonts.robotoFlex()]);
  runApp(const GenUIFormApp());

  // Frame heartbeat for Flutter web release builds. After the first paint the
  // engine can stop pumping animation frames automatically, so subsequent
  // setState() / StreamBuilder rebuilds queue up but never paint until an
  // external event (e.g. window resize) wakes it. This was confirmed in
  // production by dispatching a synthetic `resize` event with no actual size
  // change — the deferred form render painted instantly. Pumping a forced
  // frame every 200ms for the first 12s covers the cold-load window where
  // async work (LLM streaming, mascot SVG fetch) lands and needs to render.
  var ticks = 0;
  Timer.periodic(const Duration(milliseconds: 200), (timer) {
    ticks++;
    if (ticks > 60) {
      timer.cancel();
      return;
    }
    SchedulerBinding.instance.scheduleFrame();
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
