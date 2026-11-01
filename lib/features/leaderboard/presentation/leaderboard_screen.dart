import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/countries.dart';
import '../../../core/widgets/ad_banner_widget.dart';
import '../../../core/widgets/flag_icon.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/leaderboard_entry.dart';
import 'leaderboard_provider.dart';

final NumberFormat _scoreFormat = NumberFormat.decimalPattern();

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = context.watch<LeaderboardProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9AA8F7), Color(0xFF5E49D1)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(onEditProfile: () => _showProfileDialog(context)),
              if (auth.user != null && auth.isGuest) _SignInBanner(auth: auth),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: _BoardCard(board: board),
                ),
              ),
              _MyStanding(board: board),
              const AdBannerWidget(),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    showDialog<void>(context: context, builder: (_) => const _ProfileDialog());
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'GLOBAL LEADERBOARD',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.person_rounded, color: Colors.white),
            onPressed: onEditProfile,
          ),
        ],
      ),
    );
  }
}

class _SignInBanner extends StatelessWidget {
  const _SignInBanner({required this.auth});

  final AuthProvider auth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Playing as guest. Sign in to keep your score on any device.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: auth.isBusy ? null : auth.signInWithGoogle,
                  icon: auth.isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Google'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF3B2FA0),
                  ),
                ),
              ],
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  auth.error!,
                  style: const TextStyle(color: Color(0xFFFFD1D1), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.board});

  final LeaderboardProvider board;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#', style: _headerStyle)),
                SizedBox(width: 40),
                Expanded(child: Text('Username', style: _headerStyle)),
                Text('High Score', style: _headerStyle),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (board.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (board.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(board.error!, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: board.retry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (board.entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No scores yet.\nClear a level to be the first on the board!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: board.entries.length,
      itemBuilder: (context, i) {
        final e = board.entries[i];
        return _EntryRow(entry: e, isMe: e.uid == board.myUid);
      },
    );
  }

  static const _headerStyle = TextStyle(
    color: Colors.white70,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isMe});

  final LeaderboardEntry entry;
  final bool isMe;

  Color get _rankColor => switch (entry.rank) {
        1 => const Color(0xFFFFD54F),
        2 => const Color(0xFFCFD8DC),
        3 => const Color(0xFFFFAB76),
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.32) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                color: _rankColor,
                fontWeight: FontWeight.w900,
                fontSize: entry.rank <= 3 ? 17 : 15,
              ),
            ),
          ),
          FlagIcon(countryCode: entry.countryCode),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              entry.username,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isMe ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            _scoreFormat.format(entry.highScore),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Pinned under the list when the player is outside the visible top list.
class _MyStanding extends StatelessWidget {
  const _MyStanding({required this.board});

  final LeaderboardProvider board;

  @override
  Widget build(BuildContext context) {
    final standing = board.standing;
    final hasScore = standing != null;
    if (hasScore && board.isMeInTop) return const SizedBox(height: 8);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3B2FA0),
          borderRadius: BorderRadius.circular(16),
        ),
        child: hasScore
            ? _EntryRow(entry: standing, isMe: true)
            : const Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Clear a level to get your rank.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
      ),
    );
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog();

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late String _country;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<LeaderboardProvider>().profile;
    _name = TextEditingController(text: profile?.username ?? '');
    _country = isKnownCountry(profile?.countryCode) ? profile!.countryCode : '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await context
        .read<LeaderboardProvider>()
        .updateProfile(username: _name.text, countryCode: _country);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      title: const Text('Your profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              maxLength: PlayerProfile.maxNameLength,
              decoration: InputDecoration(labelText: 'Username', errorText: _error),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _country,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Country'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Not set')),
                for (final c in kCountries.entries)
                  DropdownMenuItem(
                    value: c.key,
                    child: Row(
                      children: [
                        FlagIcon(countryCode: c.key, width: 24, height: 16),
                        const SizedBox(width: 10),
                        Expanded(child: Text(c.value, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _country = v ?? ''),
            ),
            if (auth.user != null && !auth.isGuest) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await auth.signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
