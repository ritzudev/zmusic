import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'dart:typed_data';

class TaggerTestApp extends StatefulWidget {
  const TaggerTestApp({super.key});

  @override
  State<TaggerTestApp> createState() => _TaggerTestAppState();
}

class _TaggerTestAppState extends State<TaggerTestApp> {
  Tag? _tag;
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
    if (_tag == null) return;
    debugPrint(
      'YT_DEBUG: Poblado controladores con Artist: ${_tag!.artist}, Title: ${_tag!.title}',
    );
    _artistController.text = _tag!.artist ?? '';
    _titleController.text = _tag!.title ?? '';
    _albumController.text = _tag!.album ?? '';
    _yearController.text = _tag!.year ?? '';
    _genreController.text = _tag!.genre ?? '';
  }

  Future<void> _pickAndLoadMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      try {
        final tagger = FlutterAudioTagger();
        Tag? tag;

        try {
          tag = await tagger.getAllTags(path);
          debugPrint('TAG_DEBUG: Leído con flutter_audio_tagger');
        } catch (e) {
          debugPrint(
            'TAG_DEBUG: ⚠️ Plugin nativo falló en lectura. Intentando con AMR...',
          );
          final file = File(path);
          final metadata = amr.readMetadata(file, getImage: true);
          tag = Tag(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            year: metadata.year?.year.toString(),
            genre: metadata.genres.join(', '),
            artwork: metadata.pictures.isNotEmpty
                ? metadata.pictures.first.bytes
                : null,
          );
          debugPrint('TAG_DEBUG: ✅ Leído con éxito usando fallback de AMR');
        }

        debugPrint('TAG_DEBUG: === Resumen de Datos ===');
        debugPrint('TAG_DEBUG: Título: ${tag?.title}');
        debugPrint('TAG_DEBUG: Artista: ${tag?.artist}');
        debugPrint(
          'TAG_DEBUG: Portada: ${tag?.artwork != null ? '${tag!.artwork!.length} bytes' : 'Nula'}',
        );
        debugPrint('TAG_DEBUG: =======================');

        setState(() {
          _currentFilePath = path;
          _tag = tag;
          _isEditing = false;
        });
        _populateControllers();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al procesar archivo: $e')),
          );
        }
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_currentFilePath == null) return;
    debugPrint(
      'Iniciando guardado con flutter_audio_tagger en: $_currentFilePath',
    );

    try {
      final tagger = FlutterAudioTagger();
      final newTag = Tag(
        title: _titleController.text,
        artist: _artistController.text,
        album: _albumController.text,
        year: _yearController.text,
        genre: _genreController.text,
        artwork: _tag?.artwork,
      );

      bool success = false;
      Uint8List? musicData;

      try {
        debugPrint('TAG_DEBUG: Intento 1: editTagsAndArtwork (con portada)...');
        final result = await tagger.editTagsAndArtwork(
          newTag,
          _currentFilePath!,
        );
        musicData = result.musicData;
        success = true;
      } catch (e) {
        debugPrint(
          'TAG_DEBUG: ⚠️ Falló Intento 1. Probando Intento 2: Solo Texto...',
        );
        try {
          final result = await tagger.editTags(newTag, _currentFilePath!);
          musicData = result.musicData;
          success = true;
        } catch (e2) {
          debugPrint(
            'TAG_DEBUG: ⚠️ Falló Intento 2. Probando Intento 3: Fallback AMR...',
          );
          try {
            final file = File(_currentFilePath!);
            amr.updateMetadata(file, (m) {
              m.setTitle(_titleController.text);
              m.setArtist(_artistController.text);
              m.setAlbum(_albumController.text);
            });
            await Future.delayed(const Duration(milliseconds: 500));
            success = true;
          } catch (e3) {
            throw 'Todos los métodos de guardado fallaron.';
          }
        }
      }

      if (musicData != null) {
        final originalFile = File(_currentFilePath!);
        final directory = originalFile.parent.path;
        final fileName = originalFile.path
            .split(Platform.isWindows ? '\\' : '/')
            .last;
        final dotIndex = fileName.lastIndexOf('.');

        String newPath;
        if (dotIndex != -1) {
          var nameOnly = fileName.substring(0, dotIndex);
          final extension = fileName.substring(dotIndex);
          if (!nameOnly.endsWith('_tagged')) nameOnly = '${nameOnly}_tagged';
          newPath = '$directory/$nameOnly$extension';
        } else {
          newPath = originalFile.path.endsWith('_tagged')
              ? originalFile.path
              : '${originalFile.path}_tagged';
        }

        final newFile = File(newPath);
        await newFile.writeAsBytes(musicData);
        _currentFilePath = newPath;
      }

      if (success) {
        // Refrescar datos
        final refreshedTag = await _readAppliedTags(_currentFilePath!);
        setState(() {
          _tag = refreshedTag;
          _isEditing = false;
        });
        _populateControllers();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cambios guardados con éxito (Sistema Fallback)'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e, stack) {
      debugPrint('ERROR AL GUARDAR: $e');
      debugPrint('STACKTRACE: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editor de Etiquetas (Tagger)"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_tag != null)
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
            child: _tag != null
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
    final hasArtwork = _tag?.artwork != null;

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
                          image: MemoryImage(_tag!.artwork!),
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

  Future<Tag?> _readAppliedTags(String path) async {
    try {
      final tagger = FlutterAudioTagger();
      return await tagger.getAllTags(path);
    } catch (e) {
      final file = File(path);
      final metadata = amr.readMetadata(file, getImage: true);
      return Tag(
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        artwork: metadata.pictures.isNotEmpty
            ? metadata.pictures.first.bytes
            : null,
      );
    }
  }
}
