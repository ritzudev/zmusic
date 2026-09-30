import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart' hide PlaylistModel;
import 'package:zmusic/models/playlist_model.dart';
import 'package:zmusic/models/song_model.dart';
import 'package:zmusic/providers/audio_player_provider.dart';
import 'package:zmusic/providers/music_library_provider.dart';
import 'package:zmusic/providers/playlist_provider.dart';
import 'package:zmusic/services/typing_state.dart';
import 'package:zmusic/widgets/artwork_widget.dart';
import 'package:zmusic/widgets/music_player_controls.dart';

class PlaylistDetailScreen extends ConsumerWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  void _showRenameDialog(BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (context) => _DetailRenameDialog(playlist: playlist),
    );
  }


  void _showDeleteDialog(BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lista'),
        content: Text('¿Estás seguro de que deseas eliminar "${playlist.name}"? Las canciones no se borrarán del dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              ref.read(playlistProvider.notifier).deletePlaylist(playlist.id);
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // Screen
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showAddSongsModal(BuildContext context, WidgetRef ref, PlaylistModel playlist) {
    final library = ref.read(musicLibraryProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSongsToPlaylistModal(
        playlist: playlist,
        allSongs: library,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playlists = ref.watch(playlistProvider);
    final playlist = playlists.firstWhere(
      (p) => p.id == playlistId,
      orElse: () => PlaylistModel(id: '', name: 'Lista', songIds: [], createdAt: 0),
    );

    if (playlist.id.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Lista no encontrada')),
      );
    }

    final songs = ref.watch(playlistSongsProvider(playlistId));
    final currentTrack = ref.watch(audioPlayerProvider).currentTrack;

    // Calcular duración total
    int totalSeconds = 0;
    for (final s in songs) {
      if (s.duration != null) {
        totalSeconds += s.duration!.inSeconds;
      }
    }
    final totalDurationStr = totalSeconds > 3600
        ? '${totalSeconds ~/ 3600} h ${(totalSeconds % 3600) ~/ 60} min'
        : '${totalSeconds ~/ 60} min';

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              title: Text(
                playlist.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 8),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                          theme.colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                  if (songs.isNotEmpty)
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.25,
                        child: ArtworkWidget(
                          id: songs.first.songId,
                          type: ArtworkType.AUDIO,
                          filePath: songs.first.filePath,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.queue_music_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) {
                  HapticFeedback.lightImpact();
                  if (value == 'rename') {
                    _showRenameDialog(context, ref, playlist);
                  } else if (value == 'add') {
                    _showAddSongsModal(context, ref, playlist);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, ref, playlist);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Añadir canciones'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Renombrar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        SizedBox(width: 12),
                        Text('Eliminar lista', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Acciones y resumen
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${songs.length} canciones • $totalDurationStr",
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Añadir canciones',
                        onPressed: () => _showAddSongsModal(context, ref, playlist),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: songs.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(audioPlayerProvider.notifier)
                                      .setPlaylistAndPlay(songs, initialIndex: 0);
                                },
                          icon: const Icon(Icons.play_arrow_rounded, size: 22),
                          label: const Text(
                            "Reproducir",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: songs.isEmpty
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  ref
                                      .read(audioPlayerProvider.notifier)
                                      .playAllShuffled(songs);
                                },
                          icon: const Icon(Icons.shuffle_rounded, size: 20),
                          label: const Text(
                            "Aleatorio",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Lista de canciones
          if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note_rounded,
                        size: 64,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Esta lista está vacía",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Añade canciones desde tu biblioteca",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showAddSongsModal(context, ref, playlist),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text("Añadir canciones"),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: currentTrack != null ? 90 : 24,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final song = songs[index];
                    final isCurrent = currentTrack?.id == song.id;

                    return Dismissible(
                      key: Key('pl_${playlist.id}_${song.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      onDismissed: (_) {
                        ref
                            .read(playlistProvider.notifier)
                            .removeSongFromPlaylist(playlist.id, song.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Eliminada de "${playlist.name}"'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onTap: () {
                          ref
                              .read(audioPlayerProvider.notifier)
                              .setPlaylistAndPlay(songs, initialIndex: index);
                        },
                        leading: ArtworkWidget(
                          id: song.songId,
                          type: ArtworkType.AUDIO,
                          filePath: song.filePath,
                          width: 48,
                          height: 48,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                            color: isCurrent ? theme.colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                          tooltip: 'Quitar de la lista',
                          onPressed: () {
                            ref
                                .read(playlistProvider.notifier)
                                .removeSongFromPlaylist(playlist.id, song.id);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: songs.length,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: currentTrack != null
          ? const SafeArea(
              child: MusicPlayerControls(showMiniPlayer: true),
            )
          : null,
    );
  }
}

class _AddSongsToPlaylistModal extends ConsumerStatefulWidget {
  final PlaylistModel playlist;
  final List<MusicTrack> allSongs;

  const _AddSongsToPlaylistModal({
    required this.playlist,
    required this.allSongs,
  });

  @override
  ConsumerState<_AddSongsToPlaylistModal> createState() =>
      _AddSongsToPlaylistModalState();
}

class _AddSongsToPlaylistModalState extends ConsumerState<_AddSongsToPlaylistModal> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPlaylist = ref
        .watch(playlistProvider)
        .firstWhere((p) => p.id == widget.playlist.id, orElse: () => widget.playlist);

    final filtered = widget.allSongs.where((s) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      return s.title.toLowerCase().contains(q) || s.artist.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Añadir a ${widget.playlist.name}",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Listo"),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              onChanged: (val) => setState(() => _search = val),
              decoration: InputDecoration(
                hintText: "Buscar canciones...",
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final song = filtered[index];
                final isAdded = currentPlaylist.songIds.contains(song.id);

                return ListTile(
                  leading: ArtworkWidget(
                    id: song.songId,
                    type: ArtworkType.AUDIO,
                    filePath: song.filePath,
                    width: 42,
                    height: 42,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(
                      isAdded
                          ? Icons.check_circle_rounded
                          : Icons.add_circle_outline_rounded,
                      color: isAdded
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      ref
                          .read(playlistProvider.notifier)
                          .toggleSongInPlaylist(widget.playlist.id, song.id);
                    },
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref
                        .read(playlistProvider.notifier)
                        .toggleSongInPlaylist(widget.playlist.id, song.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRenameDialog extends ConsumerStatefulWidget {
  final PlaylistModel playlist;
  const _DetailRenameDialog({required this.playlist});

  @override
  ConsumerState<_DetailRenameDialog> createState() =>
      _DetailRenameDialogState();
}

class _DetailRenameDialogState
    extends ConsumerState<_DetailRenameDialog> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.playlist.name);
    _focusNode.addListener(() {
      TypingState.isTyping = _focusNode.hasFocus;
    });
    TypingState.isTyping = true;
  }

  @override
  void dispose() {
    TypingState.isTyping = false;
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final newName = _controller.text.trim();
    if (newName.isNotEmpty) {
      ref
          .read(playlistProvider.notifier)
          .renamePlaylist(widget.playlist.id, newName);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Renombrar lista'),
      content: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Nuevo nombre...',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

