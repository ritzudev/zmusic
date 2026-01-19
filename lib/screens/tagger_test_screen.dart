import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:file_picker/file_picker.dart';

class TaggerTestApp extends StatefulWidget {
  const TaggerTestApp({super.key});

  @override
  State<TaggerTestApp> createState() => _TaggerTestAppState();
}

class _TaggerTestAppState extends State<TaggerTestApp> {
  AudioMetadata? _metadata;
  String? _currentFilePath;
  bool _isEditing = false;

  // Controllers
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();

  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  void _populateControllers() {
    if (_metadata == null) return;
    debugPrint(
      'YT_DEBUG: Poblado controladores con Artist: ${_metadata!.artist}, Title: ${_metadata!.title}',
    );
    _artistController.text = _metadata!.artist ?? '';
    _titleController.text = _metadata!.title ?? '';
    _albumController.text = _metadata!.album ?? '';
    _yearController.text = _metadata!.year?.toString() ?? '';
    _genreController.text = _metadata!.genres.join(', ');
  }

  Future<void> _pickAndLoadMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      try {
        final file = File(path);
        final metadata = readMetadata(file, getImage: true);

        debugPrint(
          'YT_DEBUG: Metadatos cargados. Imágenes encontradas: ${metadata.pictures.length}',
        );
        for (var i = 0; i < metadata.pictures.length; i++) {
          final pic = metadata.pictures[i];
          debugPrint(
            'YT_DEBUG: Imagen $i: ${pic.mimetype}, Tamaño: ${pic.bytes.length} bytes, Tipo: ${pic.pictureType}',
          );
        }

        setState(() {
          _currentFilePath = path;
          _metadata = metadata;
          _isEditing = false;
        });
        _populateControllers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al leer metadatos: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_currentFilePath == null) return;
    final file = File(_currentFilePath!);
    debugPrint('Iniciando guardado en: $_currentFilePath');

    try {
      updateMetadata(file, (metadata) {
        debugPrint('Configurando nuevos metadatos...');
        debugPrint('Título: ${_titleController.text}');
        debugPrint('Artista: ${_artistController.text}');

        metadata.setTitle(_titleController.text);
        metadata.setArtist(_artistController.text);
        metadata.setAlbum(_albumController.text);

        if (_yearController.text.isNotEmpty) {
          final year = int.tryParse(_yearController.text);
          if (year != null) {
            debugPrint('Año: $year');
            metadata.setYear(DateTime(year));
          }
        }

        if (_genreController.text.isNotEmpty) {
          debugPrint('YT_DEBUG: Géneros: [${_genreController.text}]');
          metadata.setGenres([_genreController.text]);
        }

        // Mantener imágenes existentes si las hay
        if (_metadata != null && _metadata!.pictures.isNotEmpty) {
          debugPrint(
            'YT_DEBUG: Manteniendo ${_metadata!.pictures.length} imágenes existentes',
          );
          metadata.setPictures(_metadata!.pictures);
        }
      });
      debugPrint('YT_DEBUG: updateMetadata completado (sincrónicamente)');

      // Refrescar metadatos después de guardar
      final newMetadata = readMetadata(file, getImage: true);
      debugPrint(
        'YT_DEBUG: Metadatos refrescados. Imágenes: ${newMetadata.pictures.length}',
      );

      setState(() {
        _metadata = newMetadata;
        _isEditing = false;
      });
      _populateControllers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cambios guardados correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('ERROR AL GUARDAR: $e');
      debugPrint('STACKTRACE: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor de Etiquetas"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_metadata != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (_isEditing) _populateControllers();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickAndLoadMusic,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.music_note),
                    label: const Text("Seleccionar Música"),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 20,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text("Guardar"),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _metadata != null
                ? _buildTagCards()
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.music_note_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No se ha seleccionado música",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagCards() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildArtworkCard(),
          _buildEditableInfoCard("Artista", _artistController),
          _buildEditableInfoCard("Título", _titleController),
          _buildEditableInfoCard("Álbum", _albumController),
          _buildEditableInfoCard("Año", _yearController),
          _buildEditableInfoCard("Género", _genreController),
        ],
      ),
    );
  }

  Widget _buildArtworkCard() {
    final theme = Theme.of(context);
    final hasArtwork = _metadata?.pictures.isNotEmpty ?? false;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Portada",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: theme.colorScheme.surfaceVariant,
                  image: hasArtwork
                      ? DecorationImage(
                          image: MemoryImage(_metadata!.pictures.first.bytes),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasArtwork
                    ? Icon(
                        Icons.music_note,
                        size: 80,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableInfoCard(
    String title,
    TextEditingController controller,
  ) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          title,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _isEditing
              ? TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Ingresar $title",
                    border: InputBorder.none,
                    isDense: true,
                  ),
                )
              : Text(
                  controller.text.isEmpty ? "No establecido" : controller.text,
                  style: theme.textTheme.bodyLarge,
                ),
        ),
      ),
    );
  }
}
