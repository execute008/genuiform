import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'app/workbench_shell.dart';

void main() {
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
