import 'package:flutter/material.dart';

void main() {
  runApp(const WorkbenchApp());
}

class WorkbenchApp extends StatelessWidget {
  const WorkbenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'genuiform workbench',
      home: WorkbenchHome(),
    );
  }
}

class WorkbenchHome extends StatelessWidget {
  const WorkbenchHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('genuiform workbench')),
      body: const Center(
        child: Text('Hello workbench — Phase 0 OK'),
      ),
    );
  }
}
