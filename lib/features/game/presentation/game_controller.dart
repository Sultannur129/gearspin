import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/audio_service.dart';
import '../../shop/domain/skin.dart';
import '../domain/game_config.dart';
import '../domain/game_engine.dart';
import '../domain/game_entities.dart';
import '../domain/level_config.dart';

/// Drives the engine from a [Ticker] (vsync-locked game loop).
///
/// * As a [ChangeNotifier] it fires every frame -> only the CustomPainter
///   listens to it (cheap repaint, no widget rebuilds).
/// * [hud] only changes on gameplay events -> HUD/overlays rebuild rarely.
class GameController extends ChangeNotifier {
  GameController({
    required int levelNumber,
    Skin? skin,
    this.audio,
  })  : skin = skin ?? kDefaultSkin,
        engine = GameEngine(LevelConfig.forLevel(levelNumber)) {
    engine.onEvent = _onEvent;
  }

  final GameEngine engine;
  final AudioService? audio;

  /// Equipped projectile skin (visual only; read by the painter).
  Skin skin;

  final ValueNotifier<int> hud = ValueNotifier<int>(0);

  /// Fired once when the level is cleared (used to persist stars/score).
  void Function(GameEngine engine)? onWon;

  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _accumulator = 0;

  void start(TickerProvider vsync) {
    _ticker ??= vsync.createTicker(_onTick);
    resume();
  }

  void pause() => _ticker?.stop();

  void resume() {
    final ticker = _ticker;
    if (ticker == null || ticker.isActive) return;
    _last = Duration.zero; // Ticker elapsed restarts at zero
    ticker.start();
  }

  void _onTick(Duration elapsed) {
    // Clamp so a long hitch (app resume, GC) doesn't fast-forward the game.
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    _accumulator += dt;
    while (_accumulator >= GameConfig.fixedStep) {
      engine.step(GameConfig.fixedStep);
      _accumulator -= GameConfig.fixedStep;
    }
    notifyListeners();
  }

  /// Called on pointer-down (not tap-up) for the lowest input latency.
  void onTap() {
    if (engine.shoot()) _bumpHud();
  }

  void restart() {
    engine.reset();
    _accumulator = 0;
    _bumpHud();
  }

  bool revive() {
    final ok = engine.revive();
    if (ok) _bumpHud();
    return ok;
  }

  void _onEvent(GameEvent event) {
    if (audio != null) {
      switch (event) {
        case GameEvent.shoot:
          audio!.playSfx(Sfx.shoot);
        case GameEvent.hit:
          audio!.playSfx(Sfx.hit);
        case GameEvent.hazard:
          audio!.playSfx(Sfx.hazard);
        case GameEvent.won:
          audio!.playSfx(Sfx.win);
          onWon?.call(engine);
        case GameEvent.lost:
          audio!.playSfx(Sfx.lose);
        case GameEvent.revived:
          audio!.playSfx(Sfx.coin);
        case GameEvent.miss:
          break;
      }
    } else {
      switch (event) {
        case GameEvent.hit:
          HapticFeedback.selectionClick();
        case GameEvent.hazard:
          HapticFeedback.heavyImpact();
        case GameEvent.won:
          HapticFeedback.mediumImpact();
          onWon?.call(engine);
        case GameEvent.lost:
          HapticFeedback.mediumImpact();
        case GameEvent.shoot:
        case GameEvent.miss:
        case GameEvent.revived:
          break;
      }
    }
    _bumpHud();
  }

  void _bumpHud() => hud.value++;

  @override
  void dispose() {
    _ticker?.dispose();
    hud.dispose();
    super.dispose();
  }
}
