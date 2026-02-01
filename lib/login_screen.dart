import 'package:flutter/material.dart';
import 'auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  bool isLogin = true; // Toggle between Login and Signup

  void _authenticate() async {
    String email = _emailController.text.trim();
    String password = _passController.text.trim();
    
    if (email.isEmpty || password.isEmpty) return;

    String? error;
    if (isLogin) {
      error = await AuthService().signIn(email, password);
    } else {
      error = await AuthService().signUp(email, password);
    }

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("CivicLens", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue)),
            SizedBox(height: 40),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            SizedBox(height: 20),
            TextField(
              controller: _passController,
              decoration: InputDecoration(labelText: "Password", border: OutlineInputBorder()),
              obscureText: true,
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: _authenticate,
              style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              child: Text(isLogin ? "Login" : "Sign Up"),
            ),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? "Create new account" : "I already have an account"),
            )
          ],
        ),
      ),
    );
  }
}