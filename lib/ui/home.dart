import 'dart:math' as math;

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
    // Tabs switch instantly, like MM: a cross-fade draws both pages through
    // translucent layers for a third of a second and stutters on phones.
    final body = KeyedSubtree(key: ValueKey(_tab), child: _page());
    final fab = _tab == 0 ? const AddButton() : null; // wide layout: records tab only, like MM

    if (wide) {
      return AuroraBackground(
        child: Scaffold(
          floatingActionButton: fab,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                leading: const SizedBox(height: 20),
                destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: body),
                ),
              ),
            ],
          ),
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
/// (Alex's design reference): two tabs on each side, with labels.
class _CurvedNavBar extends StatelessWidget {
  const _CurvedNavBar({required this.tab, required this.items, required this.onTab});

  /// Gap to the screen edges, and the display corner radius of an iPhone
  /// 16 Pro; the bar's lower corners run parallel to the screen's corners.
  static const _gap = 6.0, _screenRadius = 55.0;
  final int tab;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Alex: the bar sits ~20% lower, partly over the home-indicator zone.
    final inset = math.max(0.0, MediaQuery.paddingOf(context).bottom - 18);
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
                    scale: sel ? 1.06 : 1,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(sel ? items[i].$2 : items[i].$1, size: 23, color: sel ? scheme.primary : scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$3,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? scheme.primary : scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: barH + rise + inset + _gap,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            left: _gap,
            right: _gap,
            bottom: _gap,
            height: barH + inset,
            child: PhysicalShape(
              clipper: _NotchClipper(radius: btn / 2 + 6, top: 28, bottom: inset > 0 ? _screenRadius - _gap : 22),
              color: Colors.transparent,
              shadowColor: Colors.black,
              elevation: 8,
              clipBehavior: Clip.antiAlias,
              // the same colours the bar always had
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark ? const [Color(0xFF141726), Color(0xFF0A0C16)] : const [Color(0xFFFFFFFF), Color(0xFFF4F7FF)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      item(0),
                      item(1),
                      const SizedBox(width: btn + 24),
                      item(2),
                      item(3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            child: SizedBox(
              width: btn,
              height: btn,
              child: AddButton(size: btn),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded bar with a round notch in the top middle whose shoulders curve
/// smoothly into the top edge.
class _NotchClipper extends CustomClipper<Path> {
  const _NotchClipper({required this.radius, required this.top, required this.bottom});
  final double radius, top, bottom;
  static const centerY = 6.0, fillet = 34.0; // notch centre below the top edge; shoulder radius

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height, cx = w / 2, r = radius, f = fillet;
    final bottom = math.min(this.bottom, h - top); // side arcs must not overlap
    // A fillet circle of radius f touches the top edge and the notch circle.
    final dx = math.sqrt((r + f) * (r + f) - (f - centerY) * (f - centerY));
    Offset touch(double sign) => Offset(cx + sign * dx * r / (r + f), centerY + (f - centerY) * r / (r + f));
    return Path()
      ..moveTo(0, top)
      ..arcToPoint(Offset(top, 0), radius: Radius.circular(top))
      ..lineTo(cx - dx, 0)
      ..arcToPoint(touch(-1), radius: Radius.circular(f))
      ..arcToPoint(touch(1), radius: Radius.circular(r), clockwise: false)
      ..arcToPoint(Offset(cx + dx, 0), radius: Radius.circular(f))
      ..lineTo(w - top, 0)
      ..arcToPoint(Offset(w, top), radius: Radius.circular(top))
      ..lineTo(w, h - bottom)
      ..arcToPoint(Offset(w - bottom, h), radius: Radius.circular(bottom))
      ..lineTo(bottom, h)
      ..arcToPoint(Offset(0, h - bottom), radius: Radius.circular(bottom))
      ..close();
  }

  @override
  bool shouldReclip(_NotchClipper old) => old.radius != radius || old.top != top || old.bottom != bottom;
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
              boxShadow: [BoxShadow(color: p.gradient.first.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 8))],
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
