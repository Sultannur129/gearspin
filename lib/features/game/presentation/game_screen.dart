import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/ad_service.dart';
import '../../../core/services/audio_service.dart';
import '../../leaderboard/presentation/leaderboard_provider.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../levels/presentation/level_provider.dart';
import '../../shop/domain/coin_rewards.dart';
import '../../shop/presentation/shop_provider.dart';
import '../domain/game_engine.dart';
import '../domain/game_entities.dart';
import '../domain/level_config.dart';
import 'game_controller.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.levelNumber = 1});

  final int levelNumber;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final GameController _controller;
  int _coinsEarned = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final skin = context.read<ShopProvider>().equippedSkin;
    final audio = context.read<AudioService>();
    _controller = GameController(
      levelNumber: widget.levelNumber,
      skin: skin,
      audio: audio,
    )..onWon = _onWon
     ..start(this);
  }

  Future<void> _onWon(GameEngine engine) async {
    // Grab providers before the first await (no BuildContext across gaps).
    final levels = context.read<LevelProvider>();
    final board = context.read<LeaderboardProvider>();
    final shop = context.read<ShopProvider>();
    final isFirstClear = !levels.isCompleted(engine.level.number);

    await levels.completeLevel(
      level: engine.level.number,
      stars: engine.stars,
      score: engine.score,
    );
    await board.submitScore(levels.totalBestScore);

    final coins = CoinRewards.forWin(stars: engine.stars, firstClear: isFirstClear);
    _coinsEarned = coins;
    if (coins > 0) {
      await shop.addCoins(coins);
      if (mounted) context.read<AudioService>().playSfx(Sfx.coin);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.resume();
    } else {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _revive() async {
    final granted = await context.read<AdService>().showRewarded();
    if (!mounted) return;
    if (granted) _controller.revive();
  }

  Future<void> _nextLevel() async {
    final ads = context.read<AdService>();
    if (!ads.adsRemoved) await ads.showInterstitial();
    if (!mounted) return;
    final next = (widget.levelNumber + 1).clamp(1, LevelConfig.totalLevels);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(levelNumber: next)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = _controller.engine;
    return Scaffold(
      backgroundColor: const Color(0xFFEF4A2E),
      body: Stack(
        children: [
          // Layer 0: game canvas + tap catcher. It sits *below* the HUD, so
          // pressing a HUD button never fires a shot.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _controller.onTap(),
              child: RepaintBoundary(
                child: CustomPaint(painter: GamePainter(_controller)),
              ),
            ),
          ),
          // Layer 1: HUD (rebuilds only on gameplay events).
          ValueListenableBuilder<int>(
            valueListenable: _controller.hud,
            builder: (context, _, __) => SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    level: engine.level.number,
                    score: engine.score,
                    lives: engine.lives,
                    onBack: () {
                      context.read<AudioService>().playSfx(Sfx.button);
                      Navigator.of(context).maybePop();
                    },
                    onLeaderboard: () {
                      context.read<AudioService>().playSfx(Sfx.button);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                      );
                    },
                  ),
                  const Spacer(),
                  IgnorePointer(
                    child: Column(
                      children: [
                        Text(
                          'SHOTS  ${engine.shotsLeft}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'TAP TO SHOOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Icon(Icons.touch_app_rounded, color: Colors.white, size: 56),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
          // Layer 2: win / lose overlay.
          ValueListenableBuilder<int>(
            valueListenable: _controller.hud,
            builder: (context, _, __) {
              if (engine.phase != GamePhase.won && engine.phase != GamePhase.lost) {
                return const SizedBox.shrink();
              }
              return _ResultOverlay(
                won: engine.phase == GamePhase.won,
                score: engine.score,
                stars: engine.stars,
                coinsEarned: _coinsEarned,
                canRevive: engine.canRevive,
                onRevive: () {
                  context.read<AudioService>().playSfx(Sfx.button);
                  _revive();
                },
                onRetry: () {
                  context.read<AudioService>().playSfx(Sfx.button);
                  _coinsEarned = 0;
                  _controller.restart();
                },
                onNext: widget.levelNumber < LevelConfig.totalLevels
                    ? () {
                        context.read<AudioService>().playSfx(Sfx.button);
                        _nextLevel();
                      }
                    : null,
                onMenu: () {
                  context.read<AudioService>().playSfx(Sfx.button);
                  Navigator.of(context).maybePop();
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.level,
    required this.score,
    required this.lives,
    required this.onBack,
    required this.onLeaderboard,
  });

  final int level;
  final int score;
  final int lives;
  final VoidCallback onBack;
  final VoidCallback onLeaderboard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RoundButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Level $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Score: $score',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(
                        i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
          _RoundButton(icon: Icons.emoji_events_rounded, onTap: onLeaderboard),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.22),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.won,
    required this.score,
    required this.stars,
    required this.coinsEarned,
    required this.canRevive,
    required this.onRevive,
    required this.onRetry,
    required this.onNext,
    required this.onMenu,
  });

  final bool won;
  final int score;
  final int stars;
  final int coinsEarned;
  final bool canRevive;
  final VoidCallback onRevive;
  final VoidCallback onRetry;
  final VoidCallback? onNext;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      alignment: Alignment.center,
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2A5C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              won ? 'LEVEL CLEAR!' : 'GAME OVER',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 12),
            if (won)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < stars ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFC83D),
                      size: 48,
                    ),
                ],
              ),
            const SizedBox(height: 8),
            Text('Score: $score', style: const TextStyle(fontSize: 20, color: Colors.white70)),
            if (won && coinsEarned > 0) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC83D), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '+$coinsEarned Coins',
                    style: const TextStyle(
                      color: Color(0xFFFFC83D),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            if (!won && canRevive)
              FilledButton.icon(
                onPressed: onRevive,
                icon: const Icon(Icons.ondemand_video_rounded),
                label: const Text('Revive (Watch Ad)'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6C5CFF),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            if (won && onNext != null)
              FilledButton(
                onPressed: onNext,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Next Level'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onRetry, child: const Text('Retry'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton(onPressed: onMenu, child: const Text('Menu'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
