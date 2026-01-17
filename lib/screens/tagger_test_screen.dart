import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:audiotags/audiotags.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaggerTestApp());
}

class TaggerTestApp extends StatefulWidget {
  const TaggerTestApp({super.key});

  @override
  State<TaggerTestApp> createState() => _TaggerTestAppState();
}

class _TaggerTestAppState extends State<TaggerTestApp> {
  String path = "";
  String info = "No hay información. Selecciona un archivo y dale a 'Read'.";

  @override
  void initState() {
    super.initState();
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AudioTags Example')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Archivo: ${path.split('/').last}",
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      if (Platform.isAndroid || Platform.isIOS) {
                        await Permission.storage.request();
                        // También audio para Android 13+
                        await Permission.audio.request();
                      }
                      FilePickerResult? r = await FilePicker.platform.pickFiles(
                        type: FileType.audio,
                      );
                      if (r != null) {
                        setState(() {
                          path = r.files.single.path!;
                          info =
                              "Archivo seleccionado. Dale a 'Read' para ver etiquetas.";
                        });
                      }
                    },
                    child: const Text("1. Open"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (path.isEmpty) {
                        _showSnackBar(
                          "Primero selecciona un archivo",
                          Colors.orange,
                        );
                        return;
                      }
                      try {
                        final now = DateTime.now();
                        final timestamp =
                            "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

                        _showSnackBar(
                          "Escribiendo: Test $timestamp...",
                          Colors.blue,
                        );
                        Tag tag = Tag(
                          title: "ZMusic Test $timestamp",
                          trackArtist: "ZMusic Artist",
                          album: "ZMusic Album",
                          genre: "Test Genre",
                          year: 2024,
                          pictures: [],
                        );
                        await AudioTags.write(path, tag);

                        // Notificar al sistema para que se actualice la biblioteca
                        final audioQuery = OnAudioQuery();
                        await audioQuery.scanMedia(path);

                        _showSnackBar(
                          "¡Escritura completada! ($timestamp)",
                          Colors.green,
                        );

                        // Refrescar info automáticamente
                        Tag? updatedTag = await AudioTags.read(path);
                        setState(() {
                          info =
                              """
PROPIEDADES ACTUALIZADAS ($timestamp):
Título: ${updatedTag?.title}
Artista: ${updatedTag?.trackArtist}
Álbum: ${updatedTag?.album}
Género: ${updatedTag?.genre}
Año: ${updatedTag?.year}
""";
                        });
                      } catch (e) {
                        _showSnackBar("Error al escribir: $e", Colors.red);
                      }
                    },
                    child: const Text("2. Write Test (Dynamic)"),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (path.isEmpty) {
                        _showSnackBar(
                          "Primero selecciona un archivo",
                          Colors.orange,
                        );
                        return;
                      }
                      try {
                        Tag? tag = await AudioTags.read(path);
                        setState(() {
                          info =
                              """
PROPIEDADES LEÍDAS:
Título: ${tag?.title}
Artista: ${tag?.trackArtist}
Álbum: ${tag?.album}
Género: ${tag?.genre}
Año: ${tag?.year}
Duración: ${tag?.duration}s
Imágenes: ${tag?.pictures.length}
""";
                        });
                        _showSnackBar("Lectura completada", Colors.green);
                      } catch (e) {
                        _showSnackBar("Error al leer: $e", Colors.red);
                        setState(() {
                          info = "Error al leer: $e";
                        });
                      }
                    },
                    child: const Text("3. Read Info"),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  info,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
