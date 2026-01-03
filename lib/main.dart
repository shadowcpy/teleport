import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_common.dart';

import 'package:teleport/src/rust/api/teleport.dart';
import 'package:teleport/src/rust/frb_generated.dart';

import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:teleport/src/rust/lib.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  if (!Platform.isAndroid) {
    await windowManager.ensureInitialized();
  }

  final persistentDirectory = await getApplicationDocumentsDirectory();
  final tempDirectory = await getApplicationCacheDirectory();

  var state = await AppState.init(
    persistenceDir: persistentDirectory.path,
    tempDir: tempDirectory.path,
  );

  runApp(TeleportApp(state: state));
}

class TeleportApp extends StatelessWidget {
  final AppState state;
  const TeleportApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomePage(state: state));
  }
}

class HomePage extends StatefulWidget {
  final AppState state;
  const HomePage({super.key, required this.state});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TrayListener, WindowListener {
  String? _result;
  List<(String, String)> _peers = [];
  String? _selectedPeer;
  String? _pairingInfo;
  String? _targetDir;

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      trayManager.addListener(this); // tray events
      windowManager.addListener(this); // window events
      _initBG();
    }
    _initTeleport();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.send), text: "Send"),
              Tab(icon: Icon(Icons.link), text: "Pair"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              mainAxisAlignment: .center,
              mainAxisSize: .max,
              children: [
                _peers.isEmpty
                    ? Text("No paired peers.")
                    : RadioGroup<String>(
                        groupValue: _selectedPeer,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedPeer = value;
                          });
                        },
                        child: Column(
                          children: _peers
                              .map((t) {
                                return ListTile(
                                  title: Text("${t.$1}: ${t.$2}"),
                                  leading: Radio(value: t.$2),
                                );
                              })
                              .cast<Widget>()
                              .toList(),
                        ),
                      ),
                SizedBox(height: 20),
                FilledButton.tonalIcon(
                  onPressed: _selectedPeer == null
                      ? null
                      : () async {
                          FilePickerResult? result = await FilePicker.platform
                              .pickFiles();
                          if (result == null) {
                            return;
                          }
                          var file = result.files.first;
                          await widget.state.sendFile(
                            peer: _selectedPeer!,
                            name: file.name,
                            path: file.path!,
                          );
                          setState(() {
                            _result =
                                "File \"${file.name}\" was successfully transferred";
                          });
                        },
                  label: Text("Select"),
                  icon: Icon(Icons.send),
                ),
                SizedBox(height: 20),
                if (_result != null) SelectableText("$_result"),
              ],
            ),
            Column(
              mainAxisAlignment: .center,
              mainAxisSize: .max,
              children: [
                if (_pairingInfo != null)
                  SizedBox(
                    height: 150,
                    child: PrettyQrView.data(data: _pairingInfo!),
                  ),
                SizedBox(height: 20),
                if (Platform.isAndroid)
                  FilledButton.tonalIcon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          bool didDetect = false;
                          return MobileScanner(
                            onDetect: (result) async {
                              if (didDetect) {
                                return;
                              }
                              didDetect = true;
                              Navigator.pop(context);
                              var info = result.barcodes.first.rawValue;
                              if (info != null) {
                                var random = Random();
                                var numbers = Iterable.generate(6, (_) {
                                  return random.nextInt(10);
                                }).toList();
                                showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SizedBox(
                                      height: 100,
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(),
                                            SizedBox(height: 10),
                                            Text(
                                              "Compare Code ${numbers.join()} on target device",
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                                await widget.state.pairWith(
                                  info: info,
                                  pairingCode: U8Array6(
                                    Uint8List.fromList(numbers),
                                  ),
                                );
                                var peers = await widget.state.peers();
                                setState(() {
                                  _peers = peers;
                                  _result = "Successfully paired to device";
                                });
                              }
                            },
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.link),
                    label: Text("Scan QR Code"),
                  ),
                SizedBox(height: 20),
                if (_result != null) SelectableText("$_result"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _initTeleport() async {
    var peers = await widget.state.peers();
    var pairingInfo = await widget.state.getAddr();
    var targetDir = await widget.state.getTargetDir();

    setState(() {
      _peers = peers;
      _pairingInfo = pairingInfo;
      _targetDir = targetDir;
    });

    if (_targetDir == null) {
      var target = await FilePicker.platform.getDirectoryPath(
        dialogTitle: "Select a folder",
      );
      if (target != null && target != "/") {
        await widget.state.setTargetDir(dir: target);
        setState(() {
          _targetDir = target;
        });
      }
    }

    widget.state.pairingSubscription().forEach((event) async {
      event.when(
        inboundPair: (pair) {
          showModalBottomSheet(
            context: context,
            builder: (BuildContext context) {
              return SizedBox(
                height: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Incoming Pairing Request"),
                    SizedBox(height: 10),
                    Text("Device: ${pair.friendlyName}"),
                    SizedBox(height: 10),
                    Text("Code: ${pair.pairingCode.join()}"),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FilledButton.tonal(
                          onPressed: () async {
                            Navigator.pop(context);
                            await widget.state.reactToPairing(
                              peer: pair.peer,
                              reaction: UIPairReaction.accept(ourName: ""),
                            );
                          },
                          child: Text("Accept"),
                        ),
                        FilledButton.tonal(
                          onPressed: () async {
                            Navigator.pop(context);
                            await widget.state.reactToPairing(
                              peer: pair.peer,
                              reaction: UIPairReaction.reject(),
                            );
                          },
                          child: Text("Reject"),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        completedPair: (cp) {
          setState(() {
            _result = "Paired with ${cp.friendlyName} (${cp.peer})";
          });
        },
        failedPair: (fp) {
          setState(() {
            _result = "Failed to pair with ${fp.friendlyName}: ${fp.reason}";
          });
        },
      );

      var peers = await widget.state.peers();
      setState(() {
        _peers = peers;
      });
    });

    widget.state.fileSubscription().forEach((file) async {
      if (_targetDir == null) {
        return;
      }
      var tempFile = File(file.path);
      var finalFile = await tempFile.copy("$_targetDir/${file.name}");
      await tempFile.delete(recursive: false);
      setState(() {
        _result = "Saved file in ${finalFile.path} (from ${file.peer})";
      });
    });
  }

  Future<void> _initBG() async {
    // Make the close button hide-to-tray instead of quitting:
    await windowManager.setPreventClose(true); //

    // Tray icon + menu
    await trayManager.setIcon(
      Platform.isWindows ? 'images/tray_icon.ico' : 'images/tray_icon.png',
    ); //

    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'toggle', label: 'Show/Hide'),
          MenuItem.separator(),
          MenuItem(key: 'quit', label: 'Quit'),
        ],
      ),
    ); //
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
  }

  Future<void> _toggleWindow() async {
    final visible = await windowManager.isVisible();
    if (visible) {
      await _hideWindow();
    } else {
      await _showWindow();
    }
  }

  // Left-click tray icon: toggle window (or pop up menu if you prefer)
  @override
  void onTrayIconMouseDown() async {
    await _toggleWindow();
  }

  // Right-click tray icon: show context menu
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu(); //
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case 'toggle':
        await _toggleWindow();
        break;
      case 'quit':
        // allow close and quit
        await windowManager.setPreventClose(false);
        await trayManager.destroy();
        await windowManager.destroy();
        break;
    }
  }

  // Window close button => hide to tray
  @override
  void onWindowClose() async {
    final prevent = await windowManager.isPreventClose(); //
    if (prevent) {
      await _hideWindow();
    }
  }

  @override
  void dispose() {
    if (!Platform.isAndroid) {
      trayManager.removeListener(this);
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
