import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_audio_tagger/flutter_audio_tagger.dart';
import 'package:flutter_audio_tagger/tag.dart';

class TaggerTestScreen extends StatefulWidget {
  const TaggerTestScreen({super.key});

  @override
  State<TaggerTestScreen> createState() => _TaggerTestScreenState();
}

class _TaggerTestScreenState extends State<TaggerTestScreen> {
  Tag? tag;
  String? currentFilePath;
  FlutterAudioTagger flutterAudioTagger = FlutterAudioTagger();

  // Text controllers for editing
  final TextEditingController _artistController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _albumController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _languageController = TextEditingController();
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _qualityController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();

  bool _isEditing = false;

  @override
  void dispose() {
    _artistController.dispose();
    _titleController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    _languageController.dispose();
    _composerController.dispose();
    _countryController.dispose();
    _qualityController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  void _populateControllers() {
    _artistController.text = tag?.artist ?? '';
    _titleController.text = tag?.title ?? '';
    _albumController.text = tag?.album ?? '';
    _yearController.text = tag?.year ?? '';
    _genreController.text = tag?.genre ?? '';
    _languageController.text = tag?.language ?? '';
    _composerController.text = tag?.composer ?? '';
    _countryController.text = tag?.country ?? '';
    _qualityController.text = tag?.quality ?? '';
    _lyricsController.text = tag?.lyrics ?? '';
  }

  Future<void> _saveChanges() async {
    if (currentFilePath == null) return;

    try {
      final updatedTag = Tag(
        artist: _artistController.text.isEmpty ? null : _artistController.text,
        title: _titleController.text.isEmpty ? null : _titleController.text,
        album: _albumController.text.isEmpty ? null : _albumController.text,
        year: _yearController.text.isEmpty ? null : _yearController.text,
        genre: _genreController.text.isEmpty ? null : _genreController.text,
        language: _languageController.text.isEmpty
            ? null
            : _languageController.text,
        composer: _composerController.text.isEmpty
            ? null
            : _composerController.text,
        country: _countryController.text.isEmpty
            ? null
            : _countryController.text,
        quality: _qualityController.text.isEmpty
            ? null
            : _qualityController.text,
        lyrics: _lyricsController.text.isEmpty ? null : _lyricsController.text,
        artwork: tag?.artwork,
      );

      // Save the changes
      await flutterAudioTagger.editTags(updatedTag, currentFilePath!);

      // Force UI state update BEFORE refreshing tags
      setState(() {
        _isEditing = false;
      });

      // Refresh tags to show updated data
      tag = await flutterAudioTagger.getAllTags(currentFilePath!);
      _populateControllers();

      // Update UI again after refreshing
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tags saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on FileSystemException catch (e) {
      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on ArgumentError catch (e) {
      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid input: ${e.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isEditing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving tags: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editArtwork() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );

      if (result != null && currentFilePath != null) {
        File imageFile = File(result.files.single.path!);

        // Check if image file exists
        if (!await imageFile.exists()) {
          throw const FileSystemException('Selected image file does not exist');
        }

        // Check file size (limit to 10MB)
        int fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Image file too large (max 10MB)');
        }

        Uint8List imageData = await imageFile.readAsBytes();

        await flutterAudioTagger.setArtWork(imageData, currentFilePath!);

        // Refresh tags to get updated artwork
        tag = await flutterAudioTagger.getAllTags(currentFilePath!);
        setState(() {});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Artwork updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FileSystemException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating artwork: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AudioTagger isolated test"),
        actions: [
          if (tag != null)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                  if (_isEditing) {
                    _populateControllers();
                  }
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
                  child: TextButton(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform
                          .pickFiles(
                            allowMultiple: false,
                            type: FileType.custom,
                            allowedExtensions: [
                              'mp3',
                              'ogg',
                              'flac',
                              'aiff',
                              'wav',
                              'wma',
                              'dsf',
                            ],
                          );

                      if (result != null) {
                        currentFilePath = result.files.single.path!;
                        tag = await flutterAudioTagger.getAllTags(
                          currentFilePath!,
                        );
                        _populateControllers();
                        setState(() {
                          _isEditing = false;
                        });
                      }
                    },
                    child: const Text("Pick Music"),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveChanges,
                    child: const Text("Save"),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: tag != null
                ? _buildTagCards()
                : const Center(child: Text("No music selected")),
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
          _buildEditableInfoCard("Artist", _artistController),
          _buildEditableInfoCard("Title", _titleController),
          _buildEditableInfoCard("Album", _albumController),
          _buildEditableInfoCard("Year", _yearController),
          _buildEditableInfoCard("Genre", _genreController),
          _buildEditableInfoCard("Language", _languageController),
          _buildEditableInfoCard("Composer", _composerController),
          _buildEditableInfoCard("Country", _countryController),
          _buildEditableInfoCard("Quality", _qualityController),
          _buildEditableLyricsCard(),
        ],
      ),
    );
  }

  Widget _buildArtworkCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Artwork",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _editArtwork,
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit"),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                  image: tag?.artwork != null
                      ? DecorationImage(
                          image: MemoryImage(tag!.artwork!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: tag?.artwork == null
                    ? Icon(Icons.music_note, size: 80, color: Colors.grey[600])
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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: _isEditing
            ? TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Enter $title",
                  border: const UnderlineInputBorder(),
                ),
              )
            : Text(
                controller.text.isEmpty ? "Not set" : controller.text,
                style: TextStyle(
                  fontSize: 16,
                  color: controller.text.isEmpty ? Colors.grey : null,
                ),
              ),
      ),
    );
  }

  Widget _buildEditableLyricsCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Lyrics",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isEditing
                ? TextField(
                    controller: _lyricsController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: "Enter lyrics",
                      border: OutlineInputBorder(),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _lyricsController.text.isEmpty
                          ? "No lyrics available"
                          : _lyricsController.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: _lyricsController.text.isEmpty
                            ? Colors.grey
                            : null,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
