import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zmusic/providers/invidious_provider.dart';
import 'package:zmusic/services/invidious_service.dart';
import 'package:zmusic/services/typing_state.dart';

class InvidiousSearchScreen extends ConsumerStatefulWidget {
  const InvidiousSearchScreen({super.key});

  @override
  ConsumerState<InvidiousSearchScreen> createState() =>
      _InvidiousSearchScreenState();
}

class _InvidiousSearchScreenState extends ConsumerState<InvidiousSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      TypingState.isTyping = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    if (_searchFocusNode.hasFocus) {
      TypingState.isTyping = false;
    }
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      ref.read(invidiousSearchProvider.notifier).search(query);
    }
  }

  Future<void> _startDownload(InvidiousSong song) async {
    final downloadNotifier = ref.read(invidiousDownloadProvider.notifier);
    final path = await downloadNotifier.downloadSong(song);

    if (mounted) {
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡"${song.title}" descargada con éxito!',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descargar "${song.title}"'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchAsync = ref.watch(invidiousSearchProvider);
    final downloadState = ref.watch(invidiousDownloadProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.cloud_download_rounded, color: Colors.cyanAccent, size: 26),
            SizedBox(width: 10),
            Text(
              "YouTube Invidious",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
            ),
            SizedBox(width: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  'SIN EXPLODE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Buscar cualquier canción o video de YouTube...",
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear, color: Colors.grey),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[800]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(
                          color: Colors.cyanAccent,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF1E1E1E),
                    ),
                    onSubmitted: (_) => _onSearch(),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _onSearch,
                  icon: const Icon(Icons.arrow_forward, color: Colors.black),
                ),
              ],
            ),
          ),

          // Banner de progreso de descarga si está activo
          if (downloadState.status == InvidiousDownloadStatus.fetchingStream ||
              downloadState.status == InvidiousDownloadStatus.downloading ||
              downloadState.status == InvidiousDownloadStatus.processing)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyanAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          downloadState.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (downloadState.speed.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.cyanAccent.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            downloadState.speed,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${(downloadState.progress * 100).toInt()}%',
                        style: const TextStyle(
                          color: Colors.cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: downloadState.progress,
                    backgroundColor: Colors.grey[800],
                    color: Colors.cyanAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

          // Lista de resultados
          Expanded(
            child: searchAsync.when(
              data: (songs) {
                if (songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ondemand_video_rounded,
                          size: 72,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Busca en todo YouTube vía Invidious",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Descargas directas sin captchas ni youtube_explode_dart",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: songs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isDownloadingThis =
                        downloadState.activeSongId == song.id;
                    final isDownloaded =
                        downloadState.completedSongIds.contains(song.id);

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[900]!),
                      ),
                      child: Row(
                        children: [
                          // Miniatura
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.thumbnailUrl.isNotEmpty
                                ? Image.network(
                                    song.thumbnailUrl,
                                    width: 70,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 70,
                                      height: 52,
                                      color: Colors.grey[850],
                                      child: const Icon(
                                        Icons.music_note,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 70,
                                    height: 52,
                                    color: Colors.grey[850],
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),

                          // Datos de la canción
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        song.author,
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      song.durationFormatted,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Botón de Descarga
                          if (isDownloadingThis)
                            const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                            )
                          else if (isDownloaded)
                            IconButton(
                              tooltip: 'Descargado (Toca para volver a descargar)',
                              onPressed: () => _startDownload(song),
                              icon: const Icon(
                                Icons.check_circle,
                                color: Colors.cyanAccent,
                                size: 28,
                              ),
                            )
                          else
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFF2A2A2A),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _startDownload(song),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.cyanAccent),
                    SizedBox(height: 16),
                    Text(
                      "Consultando catálogo de YouTube (Invidious)...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Error al consultar Invidious: $err",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _onSearch,
                        icon: const Icon(Icons.refresh),
                        label: const Text("Reintentar"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
