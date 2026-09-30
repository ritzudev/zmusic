import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/playlist_provider.dart';
import 'package:zmusic/services/typing_state.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart' hide PlaylistModel;

class AddToPlaylistDialog extends ConsumerStatefulWidget {
  final MusicTrack song;

  const AddToPlaylistDialog({super.key, required this.song});

  static Future<void> show(BuildContext context, MusicTrack song) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddToPlaylistDialog(song: song),
    );
  }

  @override
  ConsumerState<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends ConsumerState<AddToPlaylistDialog> {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isCreatingNew = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      TypingState.isTyping = _focusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    TypingState.isTyping = false;
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createNewPlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    HapticFeedback.mediumImpact();
    final newPl = await ref.read(playlistProvider.notifier).createPlaylist(
      name,
      initialSongIds: [widget.song.id],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Añadida a "${newPl.name}"'),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Canción cabecera
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  ArtworkWidget(
                    id: widget.song.songId,
                    type: ArtworkType.AUDIO,
                    filePath: widget.song.filePath,
                    width: 48,
                    height: 48,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 24, indent: 20, endIndent: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Añadir a lista",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (!_isCreatingNew)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCreatingNew = true;
                        });
                      },
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text("Nueva lista"),
                    ),
                ],
              ),
            ),

            // Formulario de nueva lista
            if (_isCreatingNew)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        focusNode: _focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Nombre de la lista...",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _createNewPlaylist(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _createNewPlaylist,
                      child: const Text("Crear"),
                    ),
                  ],
                ),
              ),

            // Lista de playlists existentes
            if (playlists.isEmpty && !_isCreatingNew)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.playlist_add_rounded,
                        size: 48,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No tienes listas personalizadas",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isCreatingNew = true;
                          });
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text("Crear mi primera lista"),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final pl = playlists[index];
                    final isInPlaylist = pl.songIds.contains(widget.song.id);

                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: isInPlaylist ? 0.2 : 0.08,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: isInPlaylist
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        pl.name,
                        style: TextStyle(
                          fontWeight:
                              isInPlaylist ? FontWeight.bold : FontWeight.w500,
                          color: isInPlaylist ? theme.colorScheme.primary : null,
                        ),
                      ),
                      subtitle: Text(
                        '${pl.songIds.length} canción(es)',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      trailing: Checkbox(
                        value: isInPlaylist,
                        activeColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (bool? val) {
                          HapticFeedback.selectionClick();
                          ref
                              .read(playlistProvider.notifier)
                              .toggleSongInPlaylist(pl.id, widget.song.id);
                        },
                      ),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(playlistProvider.notifier)
                            .toggleSongInPlaylist(pl.id, widget.song.id);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
