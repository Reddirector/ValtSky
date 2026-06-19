import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/prefs.dart';
import 'services/background_service.dart';
import 'ui/home_page.dart';
import 'util/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  BackgroundService.init();
  runApp(const ValtSkyApp());
}

class ValtSkyApp extends StatelessWidget {
  const ValtSkyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'ValtSky',
            debugShowCheckedModeBanner: false,
            theme: ValtSkyTheme.light(),
            darkTheme: ValtSkyTheme.dark(),
            themeMode: themeProvider.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = Prefs.selectedTheme == ThemeChoice.dark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
      Prefs.selectedTheme = ThemeChoice.light;
    } else {
      _themeMode = ThemeMode.dark;
      Prefs.selectedTheme = ThemeChoice.dark;
    }
    notifyListeners();
  }
}
