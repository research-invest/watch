import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/watch_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем сервисы
  await NotificationService.instance.initialize();
  final authService = AuthService();
  final isAuth = await authService.isAuthenticated();

  runApp(MaterialApp(
    theme: ThemeData.dark(),
    home: isAuth ? const WatchScreen() : const LoginScreen(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const WatchScreen(),
    );
  }
}

