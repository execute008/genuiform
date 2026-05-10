import 'package:flutter/material.dart';
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
