import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/theme_provider.dart';
import 'package:zmusic/services/window_service.dart';
import 'package:zmusic/services/update_service.dart';
import 'package:zmusic/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'Apariencia'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Tema Oscuro'),
                      subtitle: const Text(
                        'Alternar entre modo claro y oscuro',
                      ),
                      secondary: Icon(
                        themeState.mode == ThemeMode.dark
                            ? Icons.dark_mode
                            : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: themeState.mode == ThemeMode.dark,
                      onChanged: (val) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(
                              val ? ThemeMode.dark : ThemeMode.light,
                            );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Paleta de Colores'),
              const SizedBox(height: 8),
              Text(
                'Selecciona un color para personalizar el fondo y los acentos de la aplicación.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AppPalette.values.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final palette = AppPalette.values[index];
                    final isSelected = themeState.palette == palette;

                    final accentColor = AppTheme.paletteAccents[palette]!;
                    final bgColor = AppTheme.paletteBackgrounds[palette]!;

                    return GestureDetector(
                      onTap: () {
                        ref.read(themeProvider.notifier).setPalette(palette);
                      },
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? accentColor
                                    : Colors.white10,
                                width: 3,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            palette.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected ? accentColor : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (Platform.isWindows) ...[
                const SizedBox(height: 24),
                _buildSectionTitle(context, 'Windows'),
                const SizedBox(height: 12),
                Card(
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      return SwitchListTile(
                        title: const Text('Cerrar minimiza a la bandeja'),
                        subtitle: const Text(
                          'Si se desactiva, la aplicación se cerrará por completo',
                        ),
                        secondary: Icon(
                          Icons.window_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        value: WindowService().minimizeToTrayOnClose,
                        onChanged: (val) async {
                          await WindowService().setMinimizeToTray(val);
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'General'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Idioma'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: const Text('Notificaciones'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'Información'),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.system_update_alt),
                      title: const Text('Buscar actualizaciones'),
                      subtitle: const Text(
                        'Comprobar si hay una versión más reciente',
                      ),
                      onTap: () async {
                        UpdateService().checkForUpdates(context);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Acerca de Z Music'),
                      subtitle: const Text('Versión 0.1.0'),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
      ),
    );
  }
}
