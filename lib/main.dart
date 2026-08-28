import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controller.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController();
  await controller.boot();
  runApp(
    ChangeNotifierProvider.value(
      value: controller,
      child: const MoniCardRoot(),
    ),
  );
}

class MoniCardRoot extends StatelessWidget {
  const MoniCardRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoniCard Super',
      debugShowCheckedModeBanner: false,
      theme: buildMoniCardTheme(),
      home: const MoniCardApp(),
    );
  }
}
