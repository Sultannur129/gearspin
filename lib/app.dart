import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/ad_service.dart';
import 'core/services/audio_service.dart';
import 'core/services/iap_service.dart';
import 'features/account/data/account_data_eraser.dart';
import 'features/account/data/account_service.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/auth_provider.dart';
import 'features/leaderboard/data/leaderboard_repository.dart';
import 'features/leaderboard/presentation/leaderboard_provider.dart';
import 'features/levels/data/progress_repository.dart';
import 'features/levels/presentation/level_provider.dart';
import 'features/levels/presentation/level_select_screen.dart';
import 'features/shop/data/shop_cloud_sync.dart';
import 'features/shop/data/shop_repository.dart';
import 'features/shop/presentation/shop_provider.dart';

class GearSpinApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// [firebaseReady] is true only when Firebase initialised successfully;
  /// otherwise the app transparently runs offline (guest + local board).
  const GearSpinApp({super.key, this.firebaseReady = false});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    final AuthRepository authRepository =
        firebaseReady ? FirebaseAuthRepository() : LocalAuthRepository();
    final LeaderboardRepository leaderboardRepository =
        firebaseReady ? FirestoreLeaderboardRepository() : InMemoryLeaderboardRepository();
    final ShopCloudSync shopCloudSync =
        firebaseReady ? FirestoreShopCloudSync() : const NoopShopCloudSync();
    final AccountDataEraser accountEraser =
        firebaseReady ? FirestoreAccountDataEraser() : const LocalAccountDataEraser();

    return MultiProvider(
      providers: [
        Provider<AccountService>.value(
          value: AccountService(auth: authRepository, eraser: accountEraser),
        ),
        Provider<AudioService>(
          create: (_) => AppAudioService()..init(),
        ),
        ChangeNotifierProvider<LevelProvider>(
          create: (_) => LevelProvider(LocalProgressRepository())..load(),
        ),
        // lazy:false -> guest sign-in starts at launch, not at first use.
        ChangeNotifierProvider<AuthProvider>(
          lazy: false,
          create: (_) => AuthProvider(authRepository)..init(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, LeaderboardProvider>(
          lazy: false,
          create: (_) => LeaderboardProvider(
            leaderboardRepository,
            deviceCountry: PlatformDispatcher.instance.locale.countryCode ?? '',
          )..start(),
          update: (_, auth, board) => board!..updateUser(auth.user),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ShopProvider>(
          lazy: false,
          create: (_) => ShopProvider(
            repository: LocalShopRepository(),
            iap: createDefaultIapService(),
            cloud: shopCloudSync,
          )..init(),
          update: (_, auth, shop) => shop!..updateUser(auth.user),
        ),
        // AdService is informed of the No Ads purchase status via ShopProvider.
        ProxyProvider<ShopProvider, AdService>(
          update: (_, shop, __) => createDefaultAdService(
            isAdsRemoved: () => shop.noAds,
            navigatorKey: navigatorKey,
          ),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Gear Spin: Tap & Hit',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFFFF7A2F),
        ),
        home: const LevelSelectScreen(),
      ),
    );
  }
}
