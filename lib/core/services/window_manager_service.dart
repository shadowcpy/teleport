import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowManagerService with TrayListener, WindowListener {
  static final WindowManagerService _instance =
      WindowManagerService._internal();
  factory WindowManagerService() => _instance;
  WindowManagerService._internal();

  Future<void> init() async {
    if (Platform.isAndroid) return;

    trayManager.addListener(this);
    windowManager.addListener(this);

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await trayManager.setIcon(
      Platform.isWindows ? 'images/tray_icon.ico' : 'images/tray_icon.png',
    );
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'toggle', label: 'Show/Hide'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    );
  }

  void dispose() {
    if (Platform.isAndroid) return;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
  }

  // --- Tray & Window Listeners (Desktop) ---

  @override
  void onTrayIconMouseDown() => _toggleWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'toggle':
        await _toggleWindow();
        break;
      case 'quit':
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  @override
  void onWindowClose() async {
    final prevent = await windowManager.isPreventClose();
    if (prevent) await windowManager.hide();
  }

  Future<void> _toggleWindow() async {
    if (await windowManager.isVisible()) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }
}
