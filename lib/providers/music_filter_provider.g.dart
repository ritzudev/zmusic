// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'music_filter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MusicSearchQuery)
const musicSearchQueryProvider = MusicSearchQueryProvider._();

final class MusicSearchQueryProvider
    extends $NotifierProvider<MusicSearchQuery, String> {
  const MusicSearchQueryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'musicSearchQueryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$musicSearchQueryHash();

  @$internal
  @override
  MusicSearchQuery create() => MusicSearchQuery();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$musicSearchQueryHash() => r'ea0d597431df1ee81fb4168c81fb48fa28417c70';

abstract class _$MusicSearchQuery extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(SelectedCategory)
const selectedCategoryProvider = SelectedCategoryProvider._();

final class SelectedCategoryProvider
    extends $NotifierProvider<SelectedCategory, String> {
  const SelectedCategoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedCategoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedCategoryHash();

  @$internal
  @override
  SelectedCategory create() => SelectedCategory();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$selectedCategoryHash() => r'418e5daf427ccf5474de56ba552536c3425acd7f';

abstract class _$SelectedCategory extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(filteredSongs)
const filteredSongsProvider = FilteredSongsProvider._();

final class FilteredSongsProvider
    extends
        $FunctionalProvider<
          List<MusicTrack>,
          List<MusicTrack>,
          List<MusicTrack>
        >
    with $Provider<List<MusicTrack>> {
  const FilteredSongsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'filteredSongsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$filteredSongsHash();

  @$internal
  @override
  $ProviderElement<List<MusicTrack>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<MusicTrack> create(Ref ref) {
    return filteredSongs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<MusicTrack> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<MusicTrack>>(value),
    );
  }
}

String _$filteredSongsHash() => r'8a6f655d47896adf0396ad601537f7b259689238';
