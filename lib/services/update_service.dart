import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ota_update/ota_update.dart';

class UpdateService {
  static const String _repo = 'ritzudev/zmusic';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  Future<void> checkForUpdates(BuildContext context) async {
    // Solo funciona en Android para auto-instalación por ahora
    if (!Platform.isAndroid) return;

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final String latestVersion = (data['tag_name'] as String).replaceAll(
        'v',
        '',
      );
      final String downloadUrl = _getApkDownloadUrl(data);

      if (downloadUrl.isEmpty) return;

      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      if (_isVersionNewer(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(
            context,
            latestVersion,
            downloadUrl,
            data['body'] ?? '',
          );
        }
      }
    } catch (e) {
      debugPrint('Error chequeando actualizaciones: $e');
    }
  }

  String _getApkDownloadUrl(Map<String, dynamic> data) {
    final List assets = data['assets'];
    final apkAsset = assets.firstWhere(
      (asset) => (asset['name'] as String).endsWith('.apk'),
      orElse: () => null,
    );
    return apkAsset != null ? apkAsset['browser_download_url'] : '';
  }

  bool _isVersionNewer(String current, String latest) {
    List<int> currentParts = current.split('.').map(int.parse).toList();
    List<int> latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length; i++) {
      int currentPart = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > currentPart) return true;
      if (latestParts[i] < currentPart) return false;
    }
    return false;
  }

  void _showUpdateDialog(
    BuildContext context,
    String version,
    String url,
    String notes,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _UpdateDialog(version: version, url: url, notes: notes);
      },
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String version;
  final String url;
  final String notes;

  const _UpdateDialog({
    required this.version,
    required this.url,
    required this.notes,
  });

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double _progress = 0;
  bool _isUpdating = false;
  String _status = '';

  void _startUpdate() {
    setState(() {
      _isUpdating = true;
      _status = 'Iniciando descarga...';
    });

    try {
      OtaUpdate()
          .execute(widget.url, destinationFilename: 'zmusic_update.apk')
          .listen(
            (OtaEvent event) {
              setState(() {
                _status = _getStatusMessage(event.status);
                if (event.value != null && event.value!.isNotEmpty) {
                  _progress = double.tryParse(event.value!) ?? 0;
                }
              });

              if (event.status == OtaStatus.INSTALLING) {
                Navigator.of(context).pop();
              }
            },
            onError: (e) {
              setState(() {
                _isUpdating = false;
                _status = 'Error: $e';
              });
            },
          );
    } catch (e) {
      setState(() {
        _isUpdating = false;
        _status = 'Error al iniciar: $e';
      });
    }
  }

  String _getStatusMessage(OtaStatus status) {
    switch (status) {
      case OtaStatus.DOWNLOADING:
        return 'Descargando actualización...';
      case OtaStatus.INSTALLING:
        return 'Instalando...';
      case OtaStatus.ALREADY_RUNNING_ERROR:
        return 'Ya hay una descarga en curso';
      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
        return 'Permiso de instalación denegado';
      case OtaStatus.INTERNAL_ERROR:
        return 'Error interno';
      default:
        return 'Preparando...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Nueva versión'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Z Music v${widget.version} disponible',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (widget.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Novedades:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 100,
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(widget.notes, style: theme.textTheme.bodySmall),
              ),
            ),
          ],
          if (_isUpdating) ...[
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _progress / 100,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$_status (${_progress.toInt()}%)',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
      actions: _isUpdating
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Luego',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _startUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Actualizar ahora'),
              ),
            ],
    );
  }
}
