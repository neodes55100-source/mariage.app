import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'wedding_app_site.dart' as wedding_app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await Workmanager().initialize(wedding_app.callbackDispatcher);
  }

  await wedding_app.main();
}
