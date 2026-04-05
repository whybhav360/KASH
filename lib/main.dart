import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/database_service.dart';
import 'providers/finance_provider.dart';
import 'providers/navigation_provider.dart';
import 'widgets/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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