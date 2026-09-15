import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'app_config.dart';
import 'wedding_app_site.dart' as wedding_app;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isIOS) {
    await Workmanager().initialize(wedding_app.callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      AppConfig.iosBackgroundUniqueName,
      AppConfig.backgroundTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  await wedding_app.main();
}
