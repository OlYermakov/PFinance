import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../state/app_store.dart';
import 'accounts_page.dart';
import 'edit_transaction.dart';
import 'more_page.dart';
import 'stats_page.dart';
import 'theme.dart';
import 'transactions_page.dart';
import 'widgets.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab;
  late RecordsView _initialView;

  static const _dest = [
    (Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Записи'),
    (Icons.donut_large_outlined, Icons.donut_large_rounded, 'Статистика'),
    (Icons.account_balance_wallet_outlined, Icons.account_balance_wallet_rounded, 'Рахунки'),
    (Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'Більше'),
  ];

  @override
  void initState() {
    super.initState();
    final start = StoreScope.read(context).prefs.startPage;
    _tab = switch (start) {
      StartPage.stats => 1,
      StartPage.accounts => 2,
      _ => 0,
    };
    _initialView = switch (start) {
      StartPage.calendar => RecordsView.calendar,
      StartPage.month => RecordsView.month,
      StartPage.summary => RecordsView.summary,
      _ => RecordsView.day,
    };
  }

  Widget _page() => switch (_tab) {
        0 => TransactionsPage(initialView: _initialView),
        1 => const StatsPage(),
        2 => const AccountsPage(),
        _ => const MorePage(),
      };

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.unlocked) return const AuroraBackground(child: LockScreen());

    final wide = MediaQuery.sizeOf(context).width >= 840;
    final body = AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(_tab), child: _page()),
    );
    final fab = _tab < 3 ? const AddButton() : null;

    if (wide) {
      return AuroraBackground(
        child: Scaffold(
          floatingActionButton: fab,
          body: Row(children: [
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.85,
              leading: const SizedBox(height: 20),
              destinations: [
                for (final d in _dest)
                  NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
              ],
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body),
              ),
            ),
          ]),
        ),
      );
    }
    return AuroraBackground(
      child: Scaffold(
        extendBody: true,
        body: body,
        floatingActionButton: fab,
        bottomNavigationBar: _GlassNavBar(
          child: NavigationBar(
            height: 66,
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              HapticFeedback.selectionClick();
              setState(() => _tab = i);
            },
            destinations: [
              for (final d in _dest)
                NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [Color(0xED141726), Color(0xF20A0C16)]
                  : const [Color(0xF2FFFFFF), Color(0xF2F4F7FF)],
            ),
            border: Border(top: BorderSide(color: dark ? const Color(0x14FFFFFF) : const Color(0x1A1E2850))),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gradient "+" button with a press-bounce and a soft glow.
class AddButton extends StatefulWidget {
  const AddButton({super.key});

  @override
  State<AddButton> createState() => _AddButtonState();
}

class _AddButtonState extends State<AddButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Semantics(
      button: true,
      label: 'Додати запис',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () => openTxnEditor(context),
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutBack,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.gradient),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: p.gradient.first.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 8)),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }
}

/// 4-digit PIN lock (Settings → Пароль).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entered = '';
  bool _wrong = false;

  void _tap(String d) {
    if (_entered.length >= 4) return;
    setState(() {
      _wrong = false;
      _entered += d;
    });
    if (_entered.length == 4) {
      final store = StoreScope.read(context);
      if (_entered == store.prefs.pin) {
        store.unlock();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _wrong = true;
          _entered = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Padding(
          padding: const EdgeInsets.all(8),
          child: GlassCard(
            radius: 40,
            blur: 14,
            onTap: onTap ?? () => _tap(label),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Center(
                child: icon != null ? Icon(icon) : Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        );
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_outline_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 32),
            Text(_wrong ? 'Невірний PIN' : 'Введи PIN', style: TextStyle(color: _wrong ? scheme.error : null, fontSize: 16)),
            const SizedBox(height: 16),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 4; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.all(8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _entered.length ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.onSurfaceVariant),
                  ),
                ),
            ]),
            const SizedBox(height: 24),
            for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']])
              Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 88),
              key('0'),
              key('', icon: Icons.backspace_outlined, onTap: () {
                if (_entered.isNotEmpty) setState(() => _entered = _entered.substring(0, _entered.length - 1));
              }),
            ]),
          ]),
        ),
      ),
    );
  }
}
