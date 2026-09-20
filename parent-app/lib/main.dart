import 'package:flutter/material.dart';
import 'core/network/api_client.dart';
import 'core/network/websocket_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiClient.init();

  if (ApiClient.isAuthenticated) {
    WebSocketService().connect();
  }

  runApp(const ParentalControlParentApp());
}

class ParentalControlParentApp extends StatelessWidget {
  const ParentalControlParentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سَنَد | SANAD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: ApiClient.isAuthenticated ? const DashboardScreen() : const LoginScreen(),
    );
  }
}
