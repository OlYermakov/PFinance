import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'format.dart';
import 'glass.dart';
import 'theme.dart';

export 'glass.dart';

/// "‹ Листопад 2026 ›" switcher with a slide animation between periods.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged, this.compact = false});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = store.periodRange(month);
    final custom = store.prefs.monthStartDay != 1;
    final label = custom
        ? '${shortDayMonth(r.start)} – ${shortDayMonth(r.end.subtract(const Duration(days: 1)))}'
        : monthTitle(month);
    Widget arrow(IconData icon, String tip, int delta) => _RoundButton(
          icon: icon,
          tooltip: tip,
          onTap: () => onChanged(DateTime(month.year, month.month + delta)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        arrow(Icons.chevron_left_rounded, 'Попередній період', -1),
        SizedBox(
          width: compact ? 150 : 176,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        arrow(Icons.chevron_right_rounded, 'Наступний період', 1),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: GlassCard(
          radius: 14,
          blur: 14,
          onTap: onTap,
          child: SizedBox(width: 34, height: 34, child: Icon(icon, size: 22)),
        ),
      );
}

/// Hero card: glass tinted with the theme's aurora.
class GradientCard extends StatelessWidget {
  const GradientCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: padding ?? const EdgeInsets.all(20),
      child: child,
    );
  }
}

/// Number that animates (counts) to its new value.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.minor, this.currency, {super.key, this.style, this.sign = false});
  final int minor;
  final String currency;
  final TextStyle? style;
  final bool sign;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: minor.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(money(v.round(), currency, sign: sign), style: style),
    );
  }
}

class EmojiAvatar extends StatelessWidget {
  const EmojiAvatar({super.key, required this.emoji, required this.color, this.size = 40});
  final String emoji;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.12)],
          ),
          borderRadius: BorderRadius.circular(size * 0.34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 48, color: c.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
      ]),
    );
  }
}

/// Three-column "Дохід · Витрати · Разом" strip (Money Manager style summary).
class TotalsStrip extends StatelessWidget {
  const TotalsStrip({super.key, required this.income, required this.expense, required this.currency, this.carry});
  final int? carry; // balance carried over from earlier periods
  final int income;
  final int expense;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final store = StoreScope.of(context);
    final incColor = incomeColor(context, store);
    Widget cell(String label, int v, Color? color, {bool sign = false}) => Expanded(
          child: Column(children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            FittedBox(
              child: AnimatedMoney(v, currency,
                  sign: sign, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
            ),
          ]),
        );
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(children: [
        Row(children: [
          cell('Дохід', income, incColor),
          cell('Витрати', expense, p.expense),
          cell('Разом', income - expense + (carry ?? 0), null, sign: true),
        ]),
        if (carry != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('з них перенесено з минулих періодів: ${money(carry!, currency, sign: true)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

/// Income colour follows the "income blue / green" setting.
Color incomeColor(BuildContext context, AppStore store) =>
    store.prefs.incomeBlue ? Theme.of(context).colorScheme.primary : AppPalette.of(context).income;

String txnTitle(AppStore store, Txn t) {
  if (t.type == TxType.transfer) return 'Переказ';
  final c = store.category(t.categoryId);
  if (c == null) return 'Без категорії';
  final top = store.topCategory(t.categoryId);
  return top != null && top.id != c.id ? '${top.name} · ${c.name}' : c.name;
}

const colorChoices = <int>[
  0xFF1FB8E6, 0xFF00E5D4, 0xFF7C5CFC, 0xFF4C8CF2, 0xFF30D158, 0xFFFF9F0A, //
  0xFFFF375F, 0xFFBF5AF2, 0xFFFFD60A, 0xFF8E8E93, 0xFFE05780, 0xFF2B2B2B,
];

class ColorPickerRow extends StatelessWidget {
  const ColorPickerRow({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final c in colorChoices)
            GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == value ? Theme.of(context).colorScheme.onSurface : Colors.white24,
                    width: c == value ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      );
}

/// Section title used across pages.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          ?trailing,
        ]),
      );
}
