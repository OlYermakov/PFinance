import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../state/app_store.dart';
import 'format.dart';
import 'glass.dart';
import 'theme.dart';

export 'glass.dart';

/// "‹ Листопад 2026 ›" switcher with a slide animation between periods.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged, this.compact = false, this.year = false, this.week = false});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final bool compact;
  final bool year; // step by years and show just the year (MM "Місяці")
  final bool week; // MM «Налаштування періоду: Тижні»: [month] is a week start

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final r = week ? store.weekRange(month) : store.periodRange(month);
    final custom = week || store.prefs.monthStartDay != 1;
    final label = year
        ? '${month.year}'
        : custom
        ? '${shortDayMonth(r.start)} – ${shortDayMonth(r.end.subtract(const Duration(days: 1)))}'
        : monthTitle(month);
    Widget arrow(IconData icon, String tip, int delta) => _RoundButton(
      icon: icon,
      tooltip: tip,
      onTap: () => onChanged(week ? DateTime(month.year, month.month, month.day + 7 * delta) : DateTime(month.year, month.month + delta * (year ? 12 : 1))),
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
    return GlassCard(padding: padding ?? const EdgeInsets.all(20), child: child);
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

/// Whether a category icon was set ('•' was the old placeholder).
bool hasIcon(String? e) => e != null && e.trim().isNotEmpty && e != '•';

/// Prefix "emoji " for a label, or nothing when the category has no icon.
String iconPrefix(String? e) => hasIcon(e) ? '$e ' : '';

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
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.12)]),
      borderRadius: BorderRadius.circular(size * 0.34),
      border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
    ),
    child: hasIcon(emoji)
        ? Text(emoji, style: TextStyle(fontSize: size * 0.48))
        : Container(
            width: size * 0.26,
            height: size * 0.26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
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
      child: Column(
        children: [
          Icon(icon, size: 48, color: c.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: c),
          ),
        ],
      ),
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
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 1),
          FittedBox(
            child: AnimatedMoney(
              v,
              currency,
              sign: sign,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: color),
            ),
          ),
        ],
      ),
    );
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
      child: Column(
        children: [
          Row(
            children: [cell('Дохід', income, incColor), cell('Витрати', expense, p.expense), cell('Разом', income - expense + (carry ?? 0), null, sign: true)],
          ),
          if (carry != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'з них перенесено з минулих періодів: ${money(carry!, currency, sign: true)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// Income colour follows the "income blue / green" setting.
Color incomeColor(BuildContext context, AppStore store) => switch (store.prefs.incomeColor) {
  'blue' => const Color(0xFF4C9BF5),
  'accent' => Theme.of(context).colorScheme.primary,
  _ => AppPalette.of(context).income,
};

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
              border: Border.all(color: c == value ? Theme.of(context).colorScheme.onSurface : Colors.white24, width: c == value ? 3 : 1),
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
    child: Row(
      children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Full-screen 4-digit PIN keypad (MM "Passcode"): message, four circles and
/// a plain number pad at the bottom. [onComplete] returns false to reject
/// the code (the pad then clears and shows [errorText]).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.message, required this.onComplete, this.errorText, this.onClose, this.title = 'PIN-код'});
  final String title;
  final String message;
  final String? errorText;
  final Future<bool> Function(String code) onComplete;
  final VoidCallback? onClose;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _code = '';
  bool _wrong = false;

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message) _code = '';
  }

  Future<void> _tap(String d) async {
    if (_code.length >= 4) return;
    setState(() {
      _wrong = false;
      _code += d;
    });
    if (_code.length == 4) {
      final ok = await widget.onComplete(_code);
      if (!mounted) return;
      if (!ok) {
        HapticFeedback.heavyImpact();
        setState(() {
          _wrong = true;
          _code = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Expanded(
      child: InkWell(
        onTap: onTap ?? () => _tap(label),
        child: SizedBox(
          height: 76,
          child: Center(
            child: icon != null ? Icon(icon, size: 30) : Text(label, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300)),
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111318) : const Color(0xFFF2F3F7),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.onClose == null ? null : IconButton(icon: const Icon(Icons.close_rounded), onPressed: widget.onClose),
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(Icons.lock_rounded, size: 40, color: scheme.onSurface),
            const SizedBox(height: 20),
            Text(widget.message, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _code.length ? scheme.onSurface : Colors.transparent,
                      border: Border.all(color: scheme.onSurface, width: 1.4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child: _wrong && widget.errorText != null ? Text(widget.errorText!, style: TextStyle(color: scheme.error)) : null,
            ),
            const Spacer(flex: 3),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  for (final row in const [
                    ['1', '2', '3'],
                    ['4', '5', '6'],
                    ['7', '8', '9'],
                  ])
                    Row(children: [for (final d in row) key(d)]),
                  Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      key('0'),
                      key(
                        '',
                        icon: Icons.backspace_outlined,
                        onTap: () {
                          if (_code.isNotEmpty) setState(() => _code = _code.substring(0, _code.length - 1));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// The app's segmented switch (as «День · Календар · Місяць · Підсумок»): a
/// rounded track and a sliding gradient pill under the chosen item. Every
/// switch in the app uses this shape. [pillColors] tints the pill per item
/// (e.g. the record type colour); otherwise it is the app gradient.
class PillTabs<T> extends StatelessWidget {
  const PillTabs({super.key, required this.value, required this.items, required this.onChanged, this.pillColors, this.height = 30});
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  final Map<T, Color>? pillColors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final keys = items.keys.toList();
    final idx = keys.indexOf(value);
    final tint = pillColors?[value];
    final colors = tint == null
        ? [p.gradient.first.withValues(alpha: 0.85), p.gradient.last.withValues(alpha: 0.85)]
        : [tint.withValues(alpha: 0.85), Color.lerp(tint, Colors.white, 0.18)!.withValues(alpha: 0.85)];
    return GlassCard(
      radius: 999,
      padding: const EdgeInsets.all(3),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / keys.length;
          return SizedBox(
            height: height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutBack,
                  left: idx * w,
                  top: 0,
                  bottom: 0,
                  width: w,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(colors: colors),
                      boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 14)],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final k in keys)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(k),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontFamilyFallback: const ['Manrope'],
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: k == value ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              child: Text(items[k]!, maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Short weekday names in display order, starting from [first] (DateTime.monday..sunday).
List<String> weekdayNames(int first) => [
  for (var i = 0; i < 7; i++) const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'][(first - 1 + i) % 7],
];

/// MM's delete mark: a solid red circle with a white bar.
class MinusBadge extends StatelessWidget {
  const MinusBadge({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: AppPalette.of(context).expense, shape: BoxShape.circle),
    alignment: Alignment.center,
    child: Container(
      width: size * 0.46,
      height: 2.4,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
    ),
  );
}

/// The app's option sheet: title, optional note/preview, a list with a check.
Future<T?> chooseOption<T>(BuildContext context, String title, Map<T, String> options, T current, {String? note, Map<T, Color>? colors, Widget? preview}) =>
    showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
      builder: (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (preview != null) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: preview),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(note, style: TextStyle(fontSize: 13, height: 1.35, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          for (final e in options.entries)
            ListTile(
              title: Text(e.value, style: TextStyle(color: colors?[e.key])),
              trailing: e.key == current ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary) : null,
              onTap: () => Navigator.pop(context, e.key),
            ),
        ],
      ),
    );
