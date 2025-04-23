import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:universal_html/html.dart' as uni_html;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../pod_player.dart';
import '../utils/logger.dart';
import '../utils/video_apis.dart';
import 'pod_getx_video_controller.dart';

class PodPlayerController {
  late PodGetXVideoController _ctr;
  late String getTag;
  bool _isCtrInitialised = false;

  Object? _initializationError;

  final PlayVideoFrom playVideoFrom;
  final PodPlayerConfig podPlayerConfig;

  bool showMoreIcon;

  /// Constructor del controlador para el reproductor de video
  PodPlayerController({
    required this.playVideoFrom,
    this.podPlayerConfig = const PodPlayerConfig(),
    this.showMoreIcon = true,
  }) {
    _init();
  }

  void _init() {
    getTag = UniqueKey().toString();
    Get.config(enableLog: PodVideoPlayer.enableGetxLogs);
    _ctr = Get.put(PodGetXVideoController(), permanent: true, tag: getTag)
      ..config(
        playVideoFrom: playVideoFrom,
        playerConfig: podPlayerConfig,
      )
      ..showMenu = showMoreIcon;
  }

  /// Inicializa el reproductor de video.
  ///
  /// Si el video no se puede cargar, se lanzará una excepción.
  Future<void> initialise() async {
    if (!_isCtrInitialised) {
      _init();
    }
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      try {
        if (!_isCtrInitialised) {
          await _ctr.videoInit();
          podLog('$getTag Pod player Initialized');
        } else {
          podLog('$getTag Pod Player Controller Already Initialized');
        }
      } catch (error) {
        podLog('$getTag Pod Player Controller failed to initialize');
        _initializationError = error;
      }
    });
    await _checkAndWaitTillInitialized();
  }

  Future<void> _checkAndWaitTillInitialized() async {
    if (_ctr.controllerInitialized) {
      _isCtrInitialised = true;
      return;
    }

    /// Si se pasa un video incorrecto, nunca se cargará.
    if (_initializationError != null) {
      if (_initializationError! is Exception) {
        throw _initializationError! as Exception;
      }
      if (_initializationError! is Error) {
        throw _initializationError! as Error;
      }
      throw Exception(_initializationError.toString());
    }

    await Future<void>.delayed(const Duration(milliseconds: 500));
    await _checkAndWaitTillInitialized();
  }

  /// Getter para acceder al reproductor ExoPlayer subyacente
  dynamic get exoPlayer => _ctr.exoPlayer;

  /// Retorna la URL del video actualmente en reproducción
  String? get videoUrl => _ctr.playingVideoUrl;

  /// Retorna `true` si el reproductor de video está inicializado
  bool get isInitialised => _ctr.videoCtr?.value.isInitialized ?? false;

  /// Retorna `true` si el video está en reproducción
  bool get isVideoPlaying => _ctr.videoCtr?.value.isPlaying ?? false;

  /// Retorna `true` si el video está en estado de buffering
  bool get isVideoBuffering => _ctr.videoCtr?.value.isBuffering ?? false;

  /// Retorna `true` si el video está en modo de bucle
  bool get isVideoLooping => _ctr.videoCtr?.value.isLooping ?? false;

  /// Retorna `true` si el video está en modo pantalla completa
  bool get isFullScreen => _ctr.isFullScreen;

  /// Retorna `true` si el volumen está silenciado
  bool get isMute => _ctr.isMute;

  /// Retorna `true` si el ícono de más opciones es visible
  bool get isMoreIconVisible => _ctr.showMenu;

  /// Retorna el estado actual del video
  PodVideoState get videoState => _ctr.podVideoState;

  /// Retorna el valor actual del reproductor de video
  VideoPlayerValue? get videoPlayerValue => _ctr.videoCtr?.value;

  /// Retorna el tipo de reproductor de video
  PodVideoPlayerType get videoPlayerType => _ctr.videoPlayerType;

  //! Posiciones del video

  /// Retorna la duración total del video
  Duration get totalVideoLength => _ctr.videoDuration;

  /// Retorna la posición actual del video
  Duration get currentVideoPosition => _ctr.videoPosition;

  //! Control de reproducción

  /// Reproduce el video
  void play() => _ctr.podVideoStateChanger(PodVideoState.playing);

  /// Pausa el video
  void pause() => _ctr.podVideoStateChanger(PodVideoState.paused);

  /// Alterna entre reproducir y pausar
  void togglePlayPause() {
    isVideoPlaying ? pause() : play();
  }

  /// Agrega un listener para los cambios en el video
  void addListener(VoidCallback listener) {
    _checkAndWaitTillInitialized().then(
      (value) => _ctr.videoCtr?.addListener(listener),
    );
  }

  /// Elimina un listener registrado
  void removeListener(VoidCallback listener) {
    _checkAndWaitTillInitialized().then(
      (value) => _ctr.videoCtr?.removeListener(listener),
    );
  }

  //! Control de volumen

  /// Silencia el volumen del video
  Future<void> mute() async => _ctr.mute();

  /// Reactiva el volumen del video
  Future<void> unMute() async => _ctr.unMute();

  /// Alterna entre silenciar y reactivar el volumen
  Future<void> toggleVolume() async {
    _ctr.isMute ? await _ctr.unMute() : await _ctr.mute();
  }

  /// Libera los recursos del controlador del reproductor de video
  void dispose() {
    _isCtrInitialised = false;
    _ctr.videoCtr?.removeListener(_ctr.videoListner);
    _ctr.videoCtr?.dispose();
    _ctr.removeListenerId('podVideoState', _ctr.podStateListner);
    if (podPlayerConfig.wakelockEnabled) WakelockPlus.disable();
    Get.delete<PodGetXVideoController>(
      force: true,
      tag: getTag,
    );
    podLog('$getTag Pod player Disposed');
  }

  /// Cambia el video actual
  Future<void> changeVideo({
    required PlayVideoFrom playVideoFrom,
    PodPlayerConfig playerConfig = const PodPlayerConfig(),
  }) =>
      _ctr.changeVideo(
        playVideoFrom: playVideoFrom,
        playerConfig: playerConfig,
      );

  /// Cambia la duración del doble toque
  void setDoubeTapForwarDuration(int seconds) => _ctr.doubleTapForwardSeconds = seconds;

  /// Salta a una posición específica del video
  Future<void> videoSeekTo(Duration moment) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekTo(moment);
  }

  /// Avanza el video desde la posición actual
  Future<void> videoSeekForward(Duration duration) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekForward(duration);
  }

  /// Retrocede el video desde la posición actual
  Future<void> videoSeekBackward(Duration duration) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.seekBackward(duration);
  }

  /// Acción al hacer doble toque hacia adelante
  Future<void> doubleTapVideoForward(int seconds) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.onRightDoubleTap(seconds: seconds);
  }

  /// Acción al hacer doble toque hacia atrás
  Future<void> doubleTapVideoBackward(int seconds) async {
    await _checkAndWaitTillInitialized();
    if (!_isCtrInitialised) return;
    return _ctr.onLeftDoubleTap(seconds: seconds);
  }

  /// Habilita el modo de pantalla completa
  void enableFullScreen() {
    uni_html.document.documentElement?.requestFullscreen();
    _ctr.enableFullScreen(getTag, showMenu: showMoreIcon);
  }

  /// Deshabilita el modo de pantalla completa
  void disableFullScreen(BuildContext context) {
    uni_html.document.exitFullscreen();

    if (!_ctr.isWebPopupOverlayOpen) {
      _ctr.disableFullScreen(context, getTag);
    }
  }

  /// Listener para los cambios en la calidad del video
  void onVideoQualityChanged(VoidCallback callback) {
    _ctr.onVimeoVideoQualityChanged = callback;
  }

  /// Obtiene las URLs de YouTube para diferentes calidades
  static Future<List<VideoQalityUrls>?> getYoutubeUrls(
    String youtubeIdOrUrl, {
    bool live = false,
  }) {
    return VideoApis.getYoutubeVideoQualityUrls(youtubeIdOrUrl, live);
  }

  /// Obtiene las URLs de Vimeo para diferentes calidades
  static Future<List<VideoQalityUrls>?> getVimeoUrls(
    String videoId, {
    String? hash,
  }) {
    return VideoApis.getVimeoVideoQualityUrls(videoId, hash);
  }

  /// Oculta el overlay del video
  void hideOverlay() => _ctr.isShowOverlay(false);

  /// Muestra el overlay del video
  void showOverlay() => _ctr.isShowOverlay(true);
}
