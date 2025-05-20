import 'package:flutter/material.dart';
import 'package:flutter_random_chat/screens/splash_screen.dart';
import 'package:flutter_random_chat/services/app_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 앱 설정 초기화
  await AppPreferences.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Random Chat',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: const Color(0xFF4169E1), // 원본 앱의 색상
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.indigo,
        primaryColor: const Color(0xFF4169E1), 
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}