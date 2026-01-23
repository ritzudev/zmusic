import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

class LocalServerService {
  static final LocalServerService _instance = LocalServerService._internal();
  factory LocalServerService() => _instance;
  LocalServerService._internal();

  HttpServer? _server;
  int? _port;
  Uint8List? _currentArtworkBytes;
  String? _currentMimeType;

  int? get port => _port;

  /// Inicia el servidor en un puerto aleatorio disponible
  Future<void> start() async {
    if (_server != null) return;

    final router = Router();

    // Ruta para obtener la carátula actual
    router.get('/artwork', (Request request) {
      if (_currentArtworkBytes == null) {
        return Response.notFound('No artwork available');
      }
      return Response.ok(
        _currentArtworkBytes,
        headers: {
          'Content-Type': _currentMimeType ?? 'image/jpeg',
          'Cache-Control': 'no-cache',
        },
      );
    });

    try {
      // Usamos puerto 0 para que el sistema asigne uno libre automáticamente
      _server = await io.serve(router.call, InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
    } catch (e) {
      // Error silencioso al iniciar el servidor
    }
  }

  /// Actualiza los bytes de la carátula que el servidor enviará
  void updateArtwork(Uint8List? bytes, {String mimeType = 'image/jpeg'}) {
    _currentArtworkBytes = bytes;
    _currentMimeType = mimeType;
  }

  /// Obtiene la URL completa para la carátula
  String? get artworkUrl {
    if (_port == null) return null;
    // Añadimos un timestamp para evitar cacheo agresivo de Windows
    return 'http://localhost:$_port/artwork?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }
}
