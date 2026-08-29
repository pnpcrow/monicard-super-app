import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'controller.dart';
import 'l10n.dart';
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
    return Consumer<AppController>(
      builder: (context, controller, _) {
        final code = controller.i18n.locale;
        return MaterialApp(
          title: controller.i18n.t('appName'),
          debugShowCheckedModeBanner: false,
          theme: buildMoniCardTheme(),
          locale: Locale(code),
          supportedLocales: [for (final c in S.supported) Locale(c)],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MoniCardApp(),
        );
      },
    );
  }
}
