import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/utils/legal_links.dart';
import '../../../core/widgets/ad_banner_widget.dart';
import '../../account/presentation/delete_account_flow.dart';
import '../../game/presentation/game_screen.dart';
import '../../leaderboard/presentation/leaderboard_screen.dart';
import '../../shop/presentation/shop_provider.dart';
import '../../shop/presentation/shop_screen.dart';
import 'level_provider.dart';
import 'widgets/level_tile.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  static const int _columns = 4;
  static const double _tileHeight = 88;
  static const double _spacing = 14;
  static const double _hPadding = 20;

  final ScrollController _scroll = ScrollController();
  bool _didAutoScroll = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Once progress is loaded, bring the current level into view.
  void _scrollToCurrent(int level) {
    if (_didAutoScroll) return;
    _didAutoScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final row = (level - 1) ~/ _columns;
      final target = (row * (_tileHeight + _spacing) - 120)
          .clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  void _open(BuildContext context, LevelProvider levels, int level) {
    final audio = context.read<AudioService>();
    if (!levels.isUnlocked(level)) {
      audio.vibrate(Sfx.hazard);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            content: Text('Complete Level ${level - 1} to unlock Level $level'),
          ),
        );
      return;
    }
    audio.playSfx(Sfx.button);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(levelNumber: level)),
    );
  }

  void _showSettings(BuildContext context) {
    final audio = context.read<AudioService>();
    audio.playSfx(Sfx.button);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1B2160),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'SETTINGS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Sound Effects (SFX)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  secondary: Icon(
                    audio.isSoundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: const Color(0xFFFF7A2F),
                  ),
                  value: audio.isSoundEnabled,
                  onChanged: (val) async {
                    await audio.toggleSound();
                    setModalState(() {});
                    if (val) audio.playSfx(Sfx.shoot);
                  },
                ),
                SwitchListTile(
                  title: const Text('Haptic Vibration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  secondary: Icon(
                    audio.isVibrationEnabled ? Icons.vibration_rounded : Icons.phone_android_rounded,
                    color: const Color(0xFFFF7A2F),
                  ),
                  value: audio.isVibrationEnabled,
                  onChanged: (val) async {
                    await audio.toggleVibration();
                    setModalState(() {});
                    if (val) audio.vibrate(Sfx.hit);
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    audio.playSfx(Sfx.shoot);
                    Future.delayed(const Duration(milliseconds: 180), () {
                      audio.playSfx(Sfx.hit);
                    });
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Test Audio & Vibration'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A2F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Colors.white24),
                _SettingsLink(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => LegalLinks.open(LegalLinks.privacyPolicy),
                ),
                _SettingsLink(
                  icon: Icons.description_outlined,
                  label: 'Terms of Use',
                  onTap: () => LegalLinks.open(LegalLinks.termsOfUse),
                ),
                _SettingsLink(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete account',
                  color: const Color(0xFFFF8A8A),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    confirmAndDeleteAccount(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final levels = context.watch<LevelProvider>();
    final shop = context.watch<ShopProvider>();
    final audio = context.watch<AudioService>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3446C9), Color(0xFF4A2FA8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                levels: levels,
                coins: shop.coins,
                onSettings: () => _showSettings(context),
              ),
              Expanded(
                child: levels.isLoaded
                    ? _buildGrid(context, levels)
                    : const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
              _NoAdsBanner(
                noAds: shop.noAds,
                onTap: () {
                  audio.playSfx(Sfx.button);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  );
                },
              ),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, LevelProvider levels) {
    _scrollToCurrent(levels.currentLevel);
    const total = LevelProvider.totalLevels;

    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(_hPadding, 8, _hPadding, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columns,
        mainAxisExtent: _tileHeight,
        crossAxisSpacing: _spacing,
        mainAxisSpacing: _spacing,
      ),
      itemCount: total,
      itemBuilder: (context, index) {
        final level = index + 1;
        final unlocked = levels.isUnlocked(level);
        final stars = levels.starsOf(level);
        final state = !unlocked
            ? LevelTileState.locked
            : stars > 0
                ? LevelTileState.completed
                : LevelTileState.current;
        final hasRightNeighbour = level % _columns != 0 && level < total;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.85, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Opacity(
            opacity: ((scale - 0.85) / 0.15).clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          ),
          child: LevelTile(
            level: level,
            stars: stars,
            state: state,
            connectorWidth: hasRightNeighbour ? _spacing : 0,
            connectorActive: levels.isUnlocked(level + 1),
            onTap: () => _open(context, levels, level),
          ),
        );
      },
    );
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.levels,
    required this.coins,
    required this.onSettings,
  });

  final LevelProvider levels;
  final int coins;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final audio = context.read<AudioService>();
    final progress = levels.completedCount / LevelProvider.totalLevels;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _CircleIcon(icon: Icons.settings_rounded, onTap: onSettings),
              const Expanded(
                child: Text(
                  'Levels',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CircleIcon(
                icon: Icons.shopping_bag_rounded,
                onTap: () {
                  audio.playSfx(Sfx.button);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ShopScreen()),
                  );
                },
              ),
              const SizedBox(width: 8),
              _CircleIcon(
                icon: Icons.emoji_events_rounded,
                onTap: () {
                  audio.playSfx(Sfx.button);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFFFC83D), size: 22),
              const SizedBox(width: 4),
              Text(
                '${levels.totalStars} / ${levels.maxStars}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF7BE0A0)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: Color(0xFFFFC83D), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '$coins',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
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

class _NoAdsBanner extends StatelessWidget {
  const _NoAdsBanner({required this.onTap, this.noAds = false});

  final VoidCallback onTap;
  final bool noAds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2A1F7A),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC83D).withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Icon(
                  noAds ? Icons.verified_rounded : Icons.card_giftcard_rounded,
                  color: noAds ? const Color(0xFF2FB36B) : const Color(0xFFFF6B6B),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        noAds ? 'No-Ads Active • Skin Store' : 'Free No-Ads Upgrade',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        noAds ? 'Customize projectile skins' : 'Starry accomplishments & store',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFC83D), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
