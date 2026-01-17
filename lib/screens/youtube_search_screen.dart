import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/youtube_provider.dart';

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

  void _showDownloadConfirmation(
    BuildContext context,
    WidgetRef ref,
    List<YouTubeVideoResult> videos,
    bool isAll,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAll ? "Descargar todo" : "Descargar seleccionados"),
        content: Text(
          "¿Deseas descargar las ${videos.length} canciones ${isAll ? 'de esta lista' : 'seleccionadas'}?",
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startDownloadMultiple(context, ref, videos);
            },
            child: Text(isAll ? "Descargar todo" : "Descargar"),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownloadMultiple(
    BuildContext context,
    WidgetRef ref,
    List<YouTubeVideoResult> videos,
  ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Iniciando descarga de ${videos.length} canciones..."),
        duration: const Duration(seconds: 2),
      ),
    );

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
            TextButton(
              onPressed: () => setState(() => _selectedVideoIds.clear()),
              child: const Text("Limpiar"),
            ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Nombre de canción o URL...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(
                        0.3,
                      ),
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _onSearch,
                  icon: const Icon(Icons.send, size: 36),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de resultados
          Expanded(
            child: searchResult.when(
              data: (videos) {
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

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: ElevatedButton.icon(
                        onPressed: downloadProgress != null
                            ? null
                            : () => _showDownloadConfirmation(
                                context,
                                ref,
                                isAnySelected ? selectedVideos : videos,
                                !isAnySelected,
                              ),
                        icon: Icon(
                          isAnySelected
                              ? Icons.playlist_add_check
                              : Icons.download_for_offline,
                        ),
                        label: Text(
                          isAnySelected
                              ? "Descargar seleccionados (${selectedVideos.length})"
                              : "Descargar todo (${videos.length})",
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
      bottomNavigationBar: downloadProgress != null
          ? Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.primaryContainer,
              child: SafeArea(
                child: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Descargando: ${downloadProgress.video.title}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: downloadProgress.progress,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text("${(downloadProgress.progress * 100).toInt()}%"),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

class _YouTubeVideoCard extends ConsumerWidget {
  final YouTubeVideoResult video;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelection;

  const _YouTubeVideoCard({
    required this.video,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelection,
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
                  _showDownloadConfirmation(context, ref);
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
                onPressed: isDownloading ? null : onToggleSelection,
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

  void _showDownloadConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar descarga"),
        content: Text("¿Deseas descargar el audio de \"${video.title}\"?"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startDownload(context, ref);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Descargar"),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Iniciando descarga: ${video.title}"),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final path = await ref
          .read(youTubeDownloadProvider.notifier)
          .downloadAudio(video);

      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "¡${video.title} descargado con éxito!",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: "VER",
              textColor: theme.colorScheme.onPrimary,
              onPressed: () {
                // Ir a la biblioteca o cerrar
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
