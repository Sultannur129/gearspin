import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/audio_service.dart';
import '../domain/product_ids.dart';
import '../domain/skin.dart';
import 'shop_provider.dart';
import 'widgets/skin_preview.dart';

const _navy = Color(0xFF1B2160);
const _coinColor = Color(0xFFFFC83D);

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  StreamSubscription<String>? _messages;

  @override
  void initState() {
    super.initState();
    _messages = context.read<ShopProvider>().messages.listen((text) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)));
    });
  }

  @override
  void dispose() {
    _messages?.cancel();
    super.dispose();
  }

  Future<void> _onSkinTap(Skin skin) async {
    final shop = context.read<ShopProvider>();
    final audio = context.read<AudioService>();

    if (shop.owns(skin)) {
      audio.playSfx(Sfx.button);
      await shop.equip(skin);
      return;
    }
    if (skin.isPremium) {
      audio.playSfx(Sfx.button);
      await shop.buyProduct(skin.iapProductId!);
      return;
    }
    final price = skin.coinPrice ?? 0;
    if (shop.coins < price) {
      audio.vibrate(Sfx.hazard);
      await shop.buySkinWithCoins(skin); // emits the "not enough coins" message
      return;
    }
    audio.playSfx(Sfx.button);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unlock ${skin.name}?'),
        content: Row(
          children: [
            const Icon(Icons.monetization_on_rounded, color: _coinColor),
            const SizedBox(width: 8),
            Text('$price coins'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              audio.playSfx(Sfx.button);
              Navigator.pop(ctx, false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              audio.playSfx(Sfx.coin);
              Navigator.pop(ctx, true);
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await shop.buySkinWithCoins(skin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4B5FE8), Color(0xFF292D99)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(coins: shop.coins),
              Expanded(
                child: !shop.isLoaded
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _NoAdsCard(shop: shop),
                          const SizedBox(height: 26),
                          const Text(
                            'Customize Skins',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Choose your projectile',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 14),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.74,
                            children: [
                              for (final skin in kSkins)
                                _SkinCard(
                                  skin: skin,
                                  shop: shop,
                                  onTap: () => _onSkinTap(skin),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton(
                            onPressed: shop.restorePurchases,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'RESTORE PURCHASES',
                              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () {
              context.read<AudioService>().playSfx(Sfx.button);
              Navigator.of(context).maybePop();
            },
          ),
          const Expanded(
            child: Text(
              'Store',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_rounded, color: _coinColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAdsCard extends StatelessWidget {
  const _NoAdsCard({required this.shop});

  final ShopProvider shop;

  @override
  Widget build(BuildContext context) {
    final price = shop.priceOf(ProductIds.noAds) ?? r'$1.99';
    final buying = shop.purchasingId == ProductIds.noAds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF9CAAFF), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.block_rounded, color: Color(0xFFE5243B), size: 50),
                Text('AD', style: TextStyle(color: Color(0xFF1B2160), fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NO ADS',
                  style: TextStyle(color: _navy, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                Text(
                  shop.storeAvailable || shop.noAds ? '(Remove Ads)' : '(Store unavailable)',
                  style: TextStyle(color: _navy.withValues(alpha: 0.7), fontSize: 13),
                ),
              ],
            ),
          ),
          if (shop.noAds)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF2FB36B)),
                SizedBox(width: 4),
                Text('Active', style: TextStyle(color: _navy, fontWeight: FontWeight.w800)),
              ],
            )
          else
            FilledButton(
              onPressed: shop.storeAvailable && !shop.isPurchasing ? shop.buyNoAds : null,
              style: FilledButton.styleFrom(
                backgroundColor: _navy,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: buying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(price, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
        ],
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({required this.skin, required this.shop, required this.onTap});

  final Skin skin;
  final ShopProvider shop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final equipped = shop.isEquipped(skin);

    return Semantics(
      button: true,
      label: '${skin.name} skin',
      child: Material(
        color: _navy,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: equipped ? Colors.white : Colors.white.withValues(alpha: 0.08),
                width: equipped ? 2.5 : 1,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Column(
              children: [
                Expanded(child: SkinPreview(skin: skin)),
                Text(
                  skin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                _StatusChip(skin: skin, shop: shop),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.skin, required this.shop});

  final Skin skin;
  final ShopProvider shop;

  @override
  Widget build(BuildContext context) {
    if (shop.isEquipped(skin)) {
      return const _Chip(color: Color(0xFF2FB36B), label: 'Equipped');
    }
    if (shop.owns(skin)) {
      return const _Chip(color: Color(0xFF3A5BE0), label: 'Equip');
    }
    if (skin.isPremium) {
      final price = shop.priceOf(skin.iapProductId!) ?? r'$2.99';
      return _Chip(
        color: const Color(0xFFB07B00),
        icon: Icons.workspace_premium_rounded,
        label: price,
      );
    }
    final price = skin.coinPrice ?? 0;
    final affordable = shop.coins >= price;
    return _Chip(
      color: Colors.black.withValues(alpha: 0.3),
      icon: Icons.monetization_on_rounded,
      iconColor: _coinColor,
      label: '$price',
      dim: !affordable,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.color,
    required this.label,
    this.icon,
    this.iconColor = Colors.white,
    this.dim = false,
  });

  final Color color;
  final String label;
  final IconData? icon;
  final Color iconColor;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dim ? 0.6 : 1,
      child: Container(
        height: 26,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(13)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
