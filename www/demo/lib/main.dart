import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme/app_theme.dart';
import 'app/workbench_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-load Roboto Flex so the first paint has the real text theme metrics.
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
