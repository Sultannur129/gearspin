import 'package:flutter/material.dart';

import '../../domain/level_progress.dart';

enum LevelTileState { completed, current, locked }

/// One node of the level map: "Level N" + 3 stars, or a padlock when locked.
class LevelTile extends StatelessWidget {
  const LevelTile({
    super.key,
    required this.level,
    required this.stars,
    required this.state,
    required this.onTap,
    this.connectorWidth = 0,
    this.connectorActive = false,
  });

  final int level;
  final int stars;
  final LevelTileState state;
  final VoidCallback onTap;

  /// Width of the line drawn into the gap to the right neighbour (0 = none).
  final double connectorWidth;
  final bool connectorActive;

  @override
  Widget build(BuildContext context) {
    final locked = state == LevelTileState.locked;
    final current = state == LevelTileState.current;

    final decoration = switch (state) {
      LevelTileState.completed => BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7BE0A0), Color(0xFF2FB36B)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
      LevelTileState.current => BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6E9BFF), Color(0xFF3A5BE0)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8FB0FF).withValues(alpha: 0.7),
              blurRadius: 14,
            ),
          ],
        ),
      LevelTileState.locked => BoxDecoration(
          color: const Color(0xFF263070),
          borderRadius: BorderRadius.circular(14),
        ),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (connectorWidth > 0)
          Positioned(
            right: -connectorWidth,
            top: 0,
            bottom: 0,
            width: connectorWidth,
            child: Center(
              child: Container(
                height: 4,
                color: Colors.white.withValues(alpha: connectorActive ? 0.55 : 0.15),
              ),
            ),
          ),
        Positioned.fill(
          child: Semantics(
            button: true,
            label: locked ? 'Level $level locked' : 'Level $level, $stars stars',
            child: DecoratedBox(
              decoration: decoration,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Level',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: locked ? 0.45 : 0.9),
                        ),
                      ),
                      Text(
                        '$level',
                        style: TextStyle(
                          fontSize: locked ? 17 : 24,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: locked ? 0.5 : 1),
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (locked)
                        Icon(Icons.lock_rounded,
                            size: 18, color: Colors.white.withValues(alpha: 0.45))
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < LevelProgress.maxStars; i++)
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: i < stars
                                    ? const Color(0xFFFFC83D)
                                    : Colors.black.withValues(alpha: current ? 0.18 : 0.22),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
