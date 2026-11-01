# Gear Spin: Tap & Hit

Hyper-casual timing game. Flutter · Provider · Firebase · AdMob · IAP.

- Android `applicationId` and iOS bundle id: `com.nexalo.gearspin`

## Architecture (feature-first + clean layers)

```
lib/
├── main.dart                      # bootstrap (Firebase, MobileAds init)
├── app.dart                       # MaterialApp + MultiProvider
├── core/
│   ├── services/
│   │   ├── ad_service.dart        # AdService interface (+ Mock)   [DONE]
│   │   ├── admob_service.dart     # Banner/Interstitial/Rewarded   [TODO]
│   │   ├── auth_service.dart      # Anonymous / Google sign-in     [TODO]
│   │   ├── iap_service.dart       # in_app_purchase wrapper        [TODO]
│   │   └── audio_service.dart     # SFX / music                    [TODO]
│   ├── theme/                     # colors, text styles
│   ├── utils/                     # country code, formatters
│   └── widgets/                   # shared buttons, gradient bg
└── features/
    ├── game/                      # [DONE - starter]
    │   ├── domain/                # pure Dart: engine, entities, level generator
    │   │   ├── game_config.dart
    │   │   ├── game_entities.dart
    │   │   ├── game_engine.dart   # fixed-step sim + swept collision
    │   │   └── level_config.dart  # 120 procedural levels
    │   └── presentation/
    │       ├── game_controller.dart  # Ticker game loop
    │       ├── game_painter.dart     # CustomPainter
    │       └── game_screen.dart      # HUD, tap input, revive overlay
    ├── auth/                      # [DONE]
    │   ├── domain/auth_user.dart
    │   ├── data/auth_repository.dart       # Firebase (anon + Google link) / Local guest
    │   └── presentation/auth_provider.dart
    ├── levels/                    # [DONE]
    │   ├── data/progress_repository.dart   # SharedPrefs cache (Firestore sync: TODO)
    │   ├── domain/level_progress.dart      # stars, best score
    │   └── presentation/{level_select_screen.dart, level_provider.dart, widgets/}
    ├── leaderboard/               # [DONE]
    │   ├── data/leaderboard_repository.dart  # Firestore + in-memory (offline/tests)
    │   ├── domain/leaderboard_entry.dart     # entry, PlayerProfile, username rules
    │   └── presentation/{leaderboard_screen.dart, leaderboard_provider.dart}
    └── shop/                      # [DONE]
        ├── data/{shop_repository.dart, shop_cloud_sync.dart}
        ├── domain/{skin.dart, product_ids.dart, shop_state.dart, coin_rewards.dart}
        └── presentation/{shop_screen.dart, shop_provider.dart, widgets/}
```

## Firestore schema (suggested)

```
users/{uid}                 { username, countryCode, highScore, coins, noAds, equippedSkin, ownedSkins[] }
users/{uid}/levels/{n}      { stars, bestScore }
leaderboard (query users)   orderBy('highScore', descending).limit(100)
```

## Next steps

1. `dart pub global activate flutterfire_cli && flutterfire configure`
2. Add AdMob app IDs to `AndroidManifest.xml` / `Info.plist`
   (use Google's test IDs during development).
3. Create IAP products in Play Console / App Store Connect:
   `no_ads` ($1.99), `skin_*`.
