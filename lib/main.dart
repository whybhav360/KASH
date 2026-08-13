import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'providers/finance_provider.dart';
import 'providers/navigation_provider.dart';
import 'widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await DatabaseService.init();
    
    final financeProvider = FinanceProvider();
    await financeProvider.init();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => financeProvider),
          ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ],
        child: const Kash(),
      ),
    );
  } catch (e, stack) {
    debugPrint('FATAL ERROR DURING INIT: $e');
    debugPrint(stack.toString());
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('Failed to start KASH', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class Kash extends StatelessWidget {
  const Kash({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          primary: const Color(0xFF4A6CF7),
          secondary: const Color(0xFF6366F1),
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          bodyMedium: TextStyle(color: Color(0xFF475569)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}