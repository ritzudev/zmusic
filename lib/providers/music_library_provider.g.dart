// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_library_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MusicLibrary)
const musicLibraryProvider = MusicLibraryProvider._();

final class MusicLibraryProvider
    extends $NotifierProvider<MusicLibrary, List<MusicTrack>> {
  const MusicLibraryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'musicLibraryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$musicLibraryHash();

  @$internal
  @override
  MusicLibrary create() => MusicLibrary();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MusicTrack> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MusicTrack>>(value),
    );
  }
}

String _$musicLibraryHash() => r'e61e83cfde0db73d22bf6476aa7bc26c656f9dd0';

abstract class _$MusicLibrary extends $Notifier<List<MusicTrack>> {
  List<MusicTrack> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<MusicTrack>, List<MusicTrack>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<MusicTrack>, List<MusicTrack>>,
              List<MusicTrack>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
