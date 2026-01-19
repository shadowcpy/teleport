import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:teleport/core/services/background_service.dart';
import 'package:teleport/core/services/notification_service.dart';
import 'package:teleport/core/services/window_manager_service.dart';
import 'package:teleport/core/theme/teleport_dark_theme.dart';
import 'package:teleport/core/theme/teleport_light_theme.dart';
import 'package:teleport/data/state/teleport_store.dart';
import 'package:teleport/features/home/home_page.dart';
import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  if (!Platform.isAndroid) {
    await WindowManagerService().init();
  } else {
    await BackgroundService().init();
    await BackgroundService().startService();
  }

  debugPrint("CALLED MAIN ---->>>");

  await NotificationService().init();

  final persistentDirectory = await getApplicationSupportDirectory();

  final state = await AppState.init(persistenceDir: persistentDirectory.path);

  final store = TeleportStore(state: state, isAndroid: Platform.isAndroid);

  runApp(TeleportApp(store: store));
}

class TeleportApp extends StatelessWidget {
  final TeleportStore store;
  const TeleportApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return TeleportScope(
      notifier: store,
      child: MaterialApp(
        title: 'Teleport',
        theme: TeleportLightTheme.light(),
        darkTheme: TeleportDarkTheme.dark(),
        themeMode: ThemeMode.system,
        home: const HomePage(),
      ),
    );
  }
}
