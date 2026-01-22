// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'youtube_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(YouTubeSearch)
const youTubeSearchProvider = YouTubeSearchProvider._();

final class YouTubeSearchProvider
    extends $AsyncNotifierProvider<YouTubeSearch, YouTubeSearchResult> {
  const YouTubeSearchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'youTubeSearchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$youTubeSearchHash();

  @$internal
  @override
  YouTubeSearch create() => YouTubeSearch();
}

String _$youTubeSearchHash() => r'01f667f0acb2b33714c72c5156857e2d7b449ea1';

abstract class _$YouTubeSearch extends $AsyncNotifier<YouTubeSearchResult> {
  FutureOr<YouTubeSearchResult> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<YouTubeSearchResult>, YouTubeSearchResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<YouTubeSearchResult>, YouTubeSearchResult>,
              AsyncValue<YouTubeSearchResult>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(YouTubeDownload)
const youTubeDownloadProvider = YouTubeDownloadProvider._();

final class YouTubeDownloadProvider
    extends $NotifierProvider<YouTubeDownload, DownloadState?> {
  const YouTubeDownloadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'youTubeDownloadProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$youTubeDownloadHash();

  @$internal
  @override
  YouTubeDownload create() => YouTubeDownload();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DownloadState? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DownloadState?>(value),
    );
  }
}

String _$youTubeDownloadHash() => r'8e690e74310a54fb50be6c92928b1dedfc821249';

abstract class _$YouTubeDownload extends $Notifier<DownloadState?> {
  DownloadState? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<DownloadState?, DownloadState?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DownloadState?, DownloadState?>,
              DownloadState?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
