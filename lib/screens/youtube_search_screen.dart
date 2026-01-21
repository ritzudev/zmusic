import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/youtube_provider.dart';
import 'package:zmusic/widgets/download_status_bar.dart';

class YouTubeSearchScreen extends ConsumerStatefulWidget {
  const YouTubeSearchScreen({super.key});

  @override
  ConsumerState<YouTubeSearchScreen> createState() =>
      _YouTubeSearchScreenState();
}

class _YouTubeSearchScreenState extends ConsumerState<YouTubeSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedVideoIds = {};

  void _onSearch() {
    if (_searchController.text.trim().isNotEmpty) {
      setState(() => _selectedVideoIds.clear());
      ref.read(youTubeSearchProvider.notifier).search(_searchController.text);
    }
  }

  void _toggleSelection(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        _selectedVideoIds.add(videoId);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDownloadDialog({
    required BuildContext context,
    required WidgetRef ref,
    required List<YouTubeVideoResult> videos,
    bool isAll = false,
  }) {
    final isSingle = videos.length == 1;
    final title = isSingle
        ? "Confirmar descarga"
        : (isAll ? "Descargar todo" : "Descargar seleccionados");

    final content = isSingle
        ? "¿Deseas descargar el audio de \"${videos.first.title}\"?"
        : "¿Deseas descargar las ${videos.length} canciones ${isAll ? 'de esta lista' : 'seleccionadas'}?";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (isSingle) {
                _startSingleDownload(context, ref, videos.first);
              } else {
                _startBatchDownload(context, ref, videos);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isSingle ? "Descargar" : (isAll ? "Descargar todo" : "Descargar"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSingleDownload(
    BuildContext context,
    WidgetRef ref,
    YouTubeVideoResult video,
  ) async {
    try {
      await ref.read(youTubeDownloadProvider.notifier).downloadAudio(video);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startBatchDownload(
    BuildContext context,
    WidgetRef ref,
    List<YouTubeVideoResult> videos,
  ) async {
    await ref.read(youTubeDownloadProvider.notifier).downloadMultiple(videos);

    if (context.mounted) {
      setState(() => _selectedVideoIds.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Todas las descargas han finalizado!"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchResult = ref.watch(youTubeSearchProvider);
    final downloadProgress = ref.watch(youTubeDownloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Descargar de YouTube"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          if (_selectedVideoIds.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _selectedVideoIds.clear()),
              icon: const Icon(Icons.delete),
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
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Nombre de la canción o URL...",
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () => _searchController.clear(),
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
              ],
            ),
          ),

          // Lista de resultados
          Expanded(
            child: searchResult.when(
              data: (results) {
                final videos = results.videos;
                final isPlaylist = results.isPlaylist;

                if (videos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.youtube_searched_for,
                          size: 80,
                          color: theme.colorScheme.onSurface.withOpacity(0.2),
                        ),
                        const SizedBox(height: 16),
                        const Text("Busca música de YouTube para descargar"),
                      ],
                    ),
                  );
                }

                final selectedVideos = videos
                    .where((v) => _selectedVideoIds.contains(v.id))
                    .toList();
                final isAnySelected = _selectedVideoIds.isNotEmpty;
                final showDownloadHeader = isAnySelected || isPlaylist;

                return Column(
                  children: [
                    if (showDownloadHeader)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: ElevatedButton.icon(
                          onPressed: downloadProgress != null
                              ? null
                              : () => _showDownloadDialog(
                                  context: context,
                                  ref: ref,
                                  videos: isAnySelected
                                      ? selectedVideos
                                      : videos,
                                  isAll: !isAnySelected,
                                ),
                          icon: Icon(
                            isAnySelected
                                ? Icons.playlist_add_check
                                : Icons.download_for_offline,
                            color: Colors.white,
                          ),
                          label: Text(
                            isAnySelected
                                ? "Descargar seleccionados (${selectedVideos.length})"
                                : "Descargar todo (${videos.length})",
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: isAnySelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.primaryContainer,
                            foregroundColor: isAnySelected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: videos.length,
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          return _YouTubeVideoCard(
                            video: video,
                            isSelected: _selectedVideoIds.contains(video.id),
                            isSelectionMode: isAnySelected,
                            onToggleSelection: () => _toggleSelection(video.id),
                            onDownloadSingle: () => _showDownloadDialog(
                              context: context,
                              ref: ref,
                              videos: [video],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Error: $e")),
            ),
          ),
        ],
      ),
      // Overlay de descarga global (opcional)
      bottomNavigationBar: const DownloadStatusBar(),
    );
  }
}

class _YouTubeVideoCard extends ConsumerWidget {
  final YouTubeVideoResult video;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelection;
  final VoidCallback onDownloadSingle;

  const _YouTubeVideoCard({
    required this.video,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelection,
    required this.onDownloadSingle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDownloading = ref.watch(youTubeDownloadProvider) != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: isDownloading
            ? null
            : () {
                if (isSelectionMode || isSelected) {
                  onToggleSelection();
                } else {
                  onDownloadSingle();
                }
              },
        onLongPress: isDownloading ? null : onToggleSelection,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Miniatura
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      video.thumbnailUrl,
                      width: 100,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.check, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              // Detalles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      video.author,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    if (video.duration != null)
                      Text(
                        _formatDuration(video.duration!),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isSelected ? Icons.check_circle : Icons.download_rounded,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withOpacity(0.7),
                ),
                onPressed: isDownloading ? null : onDownloadSingle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }
}
