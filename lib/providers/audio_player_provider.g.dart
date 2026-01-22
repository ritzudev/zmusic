// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_player_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider del AudioHandler

@ProviderFor(audioHandler)
const audioHandlerProvider = AudioHandlerProvider._();

/// Provider del AudioHandler

final class AudioHandlerProvider
    extends
        $FunctionalProvider<
          AsyncValue<MusicAudioHandler>,
          MusicAudioHandler,
          FutureOr<MusicAudioHandler>
        >
    with
        $FutureModifier<MusicAudioHandler>,
        $FutureProvider<MusicAudioHandler> {
  /// Provider del AudioHandler
  const AudioHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioHandlerHash();

  @$internal
  @override
  $FutureProviderElement<MusicAudioHandler> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MusicAudioHandler> create(Ref ref) {
    return audioHandler(ref);
  }
}

String _$audioHandlerHash() => r'de13148a21efc84a814740ae508bbf60c3be99de';

/// Provider del estado del reproductor

@ProviderFor(AudioPlayer)
const audioPlayerProvider = AudioPlayerProvider._();

/// Provider del estado del reproductor
final class AudioPlayerProvider
    extends $NotifierProvider<AudioPlayer, AudioPlayerState> {
  /// Provider del estado del reproductor
  const AudioPlayerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'audioPlayerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$audioPlayerHash();

  @$internal
  @override
  AudioPlayer create() => AudioPlayer();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AudioPlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AudioPlayerState>(value),
    );
  }
}

String _$audioPlayerHash() => r'b36384fca428019422120792b07c311172a53588';

/// Provider del estado del reproductor

abstract class _$AudioPlayer extends $Notifier<AudioPlayerState> {
  AudioPlayerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AudioPlayerState, AudioPlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AudioPlayerState, AudioPlayerState>,
              AudioPlayerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
