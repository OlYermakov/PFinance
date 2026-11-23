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
    final fab = _tab == 0 ? const AddButton() : null; // wide layout: records tab only, like MM

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
        bottomNavigationBar: _CurvedNavBar(
          tab: _tab,
          items: _dest,
          onTab: (i) {
            HapticFeedback.selectionClick();
            setState(() => _tab = i);
          },
        ),
      ),
    );
  }
}

/// Rounded gradient bar with a notch in the middle that holds a round "+"
/// (Alex's design reference): two tabs on each side, icons only.
class _CurvedNavBar extends StatelessWidget {
  const _CurvedNavBar({required this.tab, required this.items, required this.onTab});
  final int tab;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final inset = MediaQuery.paddingOf(context).bottom;
    const barH = 58.0, btn = 60.0, rise = 24.0;
    Widget item(int i) {
      final sel = i == tab;
      return Expanded(
        child: Tooltip(
          message: items[i].$3,
          child: InkResponse(
            onTap: () => onTab(i),
            radius: 30,
            child: SizedBox(
              height: barH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedScale(
                    scale: sel ? 1.12 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(sel ? items[i].$2 : items[i].$1, size: 24, color: Colors.white.withValues(alpha: sel ? 1 : 0.62)),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: sel ? 5 : 0,
                    height: 5,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: barH + rise + inset + 8,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: 12,
            right: 12,
            bottom: inset + 8,
            height: barH,
            child: PhysicalShape(
              clipper: const _NotchClipper(radius: btn / 2 + 7),
              color: Colors.transparent,
              shadowColor: Colors.black,
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [for (final c in p.gradient) Color.lerp(c, const Color(0xFF8FA3B8), 0.28)!]),
                ),
                child: Row(children: [item(0), item(1), const SizedBox(width: btn + 24), item(2), item(3)]),
              ),
            ),
          ),
          const Positioned(top: 0, child: SizedBox(width: btn, height: btn, child: AddButton(size: btn))),
        ],
      ),
    );
  }
}

/// Rounded bar with a round bite out of the top middle.
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.radius});
  final double radius;

  @override
  Path getClip(Size size) {
    final bar = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.height / 2)));
    final bite = Path()..addOval(Rect.fromCircle(center: Offset(size.width / 2, 4), radius: radius));
    return Path.combine(PathOperation.difference, bar, bite);
  }

  @override
  bool shouldReclip(_NotchClipper old) => old.radius != radius;
}

/// Gradient "+" button with a press-bounce and a soft glow.
class AddButton extends StatefulWidget {
  const AddButton({super.key, this.size = 60});
  final double size;

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
            width: widget.size,
            height: widget.size,
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
  @override
  Widget build(BuildContext context) => PinPad(
        title: 'PFinance',
        message: 'Введи PIN-код',
        errorText: 'Невірний PIN-код',
        onComplete: (code) async {
          final store = StoreScope.read(context);
          if (code != store.prefs.pin) return false;
          store.unlock();
          return true;
        },
      );
}
