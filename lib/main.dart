import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';

import 'data/repository.dart';
import 'state/app_store.dart';
import 'ui/app_icon.dart';
import 'ui/home.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('uk');
  final store = AppStore(await Repository.open());
  await store.load();
  applyAppIcon(store.prefs.appIcon);
  runApp(MoneyApp(store: store));
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
            locale: const Locale('uk'),
            supportedLocales: const [Locale('uk'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
