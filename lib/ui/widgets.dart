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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.34), color.withValues(alpha: 0.12)],
          ),
          borderRadius: BorderRadius.circular(size * 0.34),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: hasIcon(emoji)
            ? Text(emoji, style: TextStyle(fontSize: size * 0.48))
            : Container(width: size * 0.26, height: size * 0.26, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
              child: Center(child: icon != null ? Icon(icon, size: 30) : Text(label, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300))),
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
        child: Column(children: [
          const Spacer(flex: 2),
          Icon(Icons.lock_rounded, size: 40, color: scheme.onSurface),
          const SizedBox(height: 20),
          Text(widget.message, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          Row(mainAxisSize: MainAxisSize.min, children: [
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
          ]),
          const SizedBox(height: 16),
          SizedBox(
            height: 20,
            child: _wrong && widget.errorText != null ? Text(widget.errorText!, style: TextStyle(color: scheme.error)) : null,
          ),
          const Spacer(flex: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(children: [
              for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9']]) Row(children: [for (final d in row) key(d)]),
              Row(children: [
                const Expanded(child: SizedBox()),
                key('0'),
                key('', icon: Icons.backspace_outlined, onTap: () {
                  if (_code.isNotEmpty) setState(() => _code = _code.substring(0, _code.length - 1));
                }),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}
