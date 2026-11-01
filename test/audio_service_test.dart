import 'package:flutter_test/flutter_test.dart';
import 'package:gear_spin/core/services/audio_service.dart';
import 'package:gear_spin/features/game/domain/game_entities.dart';
import 'package:gear_spin/features/game/presentation/game_controller.dart';

void main() {
  group('MockAudioService', () {
    test('toggles sound and vibration states', () async {
      final audio = MockAudioService();

      expect(audio.isSoundEnabled, isTrue);
      expect(audio.isVibrationEnabled, isTrue);

      await audio.toggleSound();
      expect(audio.isSoundEnabled, isFalse);

      await audio.toggleVibration();
      expect(audio.isVibrationEnabled, isFalse);

      audio.playSfx(Sfx.button);
      expect(audio.playedSfx, contains(Sfx.button));
      expect(audio.vibrations, isEmpty); // Vibration disabled
    });

    test('records sfx and vibration events when enabled', () {
      final audio = MockAudioService();

      audio.playSfx(Sfx.shoot);
      audio.playSfx(Sfx.hit);

      expect(audio.playedSfx, [Sfx.shoot, Sfx.hit]);
      expect(audio.vibrations, [Sfx.shoot, Sfx.hit]);
    });
  });

  group('GameController with AudioService', () {
    test('triggers shoot sfx on onTap()', () {
      final audio = MockAudioService();
      final controller = GameController(levelNumber: 1, audio: audio);

      controller.onTap();

      expect(audio.playedSfx, contains(Sfx.shoot));
      expect(audio.vibrations, contains(Sfx.shoot));
    });

    test('triggers win sfx and onWon callback on level clear', () {
      final audio = MockAudioService();
      var wonCalled = false;
      final controller = GameController(levelNumber: 1, audio: audio)
        ..onWon = (_) => wonCalled = true;

      // Simulate win event directly from engine
      controller.engine.onEvent?.call(GameEvent.won);

      expect(audio.playedSfx, contains(Sfx.win));
      expect(wonCalled, isTrue);
    });

    test('triggers hazard and lose sfx on game over', () {
      final audio = MockAudioService();
      final controller = GameController(levelNumber: 1, audio: audio);

      controller.engine.onEvent?.call(GameEvent.hazard);
      controller.engine.onEvent?.call(GameEvent.lost);

      expect(audio.playedSfx, [Sfx.hazard, Sfx.lose]);
    });
  });
}
