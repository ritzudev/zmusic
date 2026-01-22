import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

class WindowService extends WindowListener with TrayListener {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  bool _minimizeToTrayOnClose = true;
  SharedPreferences? _prefs;

  Future<void> init() async {
    if (!Platform.isWindows) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(this);

    // Configurar opciones de ventana (Tamaño por defecto)
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(900, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: "ZMusic",
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Evitar que la ventana se cierre automáticamente para poder interceptar el evento
    await windowManager.setPreventClose(true);

    _prefs = await SharedPreferences.getInstance();
    _minimizeToTrayOnClose =
        _prefs?.getBool('minimize_to_tray_on_close') ?? true;

    await _initSystemTray();
  }

  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTrayOnClose = value;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setBool('minimize_to_tray_on_close', value);
  }

  bool get minimizeToTrayOnClose => _minimizeToTrayOnClose;

  Future<void> _initSystemTray() async {
    // tray_manager funciona mejor con archivos .ico en Windows
    await trayManager.setIcon(
      Platform.isWindows ? 'assets/zmusic.ico' : 'assets/zmusic.png',
    );

    final Menu menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: 'Mostrar ZMusic'),
        MenuItem(key: 'hide_window', label: 'Ocultar'),
        MenuItem.separator(),
        MenuItem(key: 'exit_app', label: 'Salir'),
      ],
    );

    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  @override
  void onWindowClose() async {
    if (_minimizeToTrayOnClose) {
      await windowManager.hide();
    } else {
      exit(0);
    }
  }

  // TrayListener events
  @override
  void onTrayIconMouseDown() {
    windowManager.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      windowManager.show();
    } else if (menuItem.key == 'hide_window') {
      windowManager.hide();
    } else if (menuItem.key == 'exit_app') {
      exit(0);
    }
  }
}
