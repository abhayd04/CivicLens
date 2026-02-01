import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// 👇 THIS IS THE KEY FIX: Import the file with the NEW UI
import 'home_screen.dart'; 
// (If you named the file 'home_screen.dart', change the line above to match)

import 'auth_service.dart';
import 'login_screen.dart';
// You can remove reports_screen/map_screen imports from here 
// since they are handled inside campus_home.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // Initialize connection to database
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // Your Project Keys
      apiKey: "API_KEY_IS_HIDDEN_FOR_SECURITY",
      authDomain: "civiclens-hackathon-bdc5b.firebaseapp.com",
      projectId: "civiclens-hackathon-bdc5b",
      storageBucket: "civiclens-hackathon-bdc5b.firebasestorage.app",
      messagingSenderId: "137913571986",
      appId: "1:137913571986:web:654cfb3e29b6e79c41644b"
    ),
  );
  
  runApp(const CivicLensApp());
}

class CivicLensApp extends StatelessWidget {
  const CivicLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CivicLens',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E), 
          secondary: const Color(0xFFFF6D00), 
          surface: Colors.white,   
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      // 👇 THE AUTH GATE
      // It checks if you are logged in.
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          // 1. Loading...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          // 2. Logged In -> Show the NEW White UI
          if (snapshot.hasData) {
            return const HomeScreen(); 
          }
          // 3. Logged Out -> Show Login
          return const LoginScreen(); 
        },
      ),
    );
  }
}