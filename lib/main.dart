import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Internal imports
import 'services/workout_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://imkgonubyikokpormtsq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlta2dvbnVieWlrb2twb3JtdHNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkzMDQwMjgsImV4cCI6MjA4NDg4MDAyOH0.lkCN4WBNkShbWA_XnWZ1vR-h-toLEo-XG9QjgWG0h58',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
      ],
      child: MyApp(), // Changed from ApexLogApp to MyApp
    ),
  );
}

// Renamed class to MyApp to match your Dashboard navigation
class MyApp extends StatelessWidget {
  MyApp({super.key}); 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apex Log',
      debugShowCheckedModeBanner: false,

      // Dark theme
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),

      home: AuthGate(), 
    );
  }
}

class AuthGate extends StatelessWidget {
  AuthGate({super.key}); 

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.blue),
            ),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // Logged in → Dashboard
          return DashboardScreen(); 
        } else {
          // Not logged in → Auth
          return AuthScreen(); 
        }
      },
    );
  }
}