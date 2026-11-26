import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'data/repository.dart';
import 'l10n/l10n.dart';
import 'state/app_store.dart';
import 'ui/app_icon.dart';
import 'ui/home.dart';
import 'ui/pwa.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  AppStore.deviceLanguage = languageFor(WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag());
  final store = AppStore(await Repository.open());
  await store.load();
  applyAppIcon(store.prefs.appIcon);
  runApp(MoneyApp(store: store));
  // Ask the browser to keep the data even when the device runs low on space.
  persistStorage();
}

class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final t = themeById(store.themeId);
          return MaterialApp(
            title: 'PFinance',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(t, Brightness.light),
            darkTheme: buildTheme(t, Brightness.dark),
            themeMode: store.themeMode,
            themeAnimationDuration: const Duration(milliseconds: 450),
            themeAnimationCurve: Curves.easeOutCubic,
            locale: Locale(lang),
            supportedLocales: [for (final l in languages.keys) Locale(l)],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              applyPageColor(dark ? 0xFF111318 : 0xFFF2F3F7);
              return _iosHomeScreenFix(context, child!);
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}

/// On iPhone, the app opened from the home screen sits below the status bar
/// (status bar style "black"), so nothing covers its top edge. After the phone
/// turns, iOS still reports the status bar height as a top safe-area inset,
/// which pushed every screen down. The top inset is always 0 there.
final bool _iosHomeScreen = isIos && isStandalone;

Widget _iosHomeScreenFix(BuildContext context, Widget child) {
  if (!_iosHomeScreen) return child;
  final mq = MediaQuery.of(context);
  if (mq.padding.top == 0 && mq.viewPadding.top == 0) return child;
  return MediaQuery(
    data: mq.copyWith(
      padding: mq.padding.copyWith(top: 0),
      viewPadding: mq.viewPadding.copyWith(top: 0),
    ),
    child: child,
  );
}
