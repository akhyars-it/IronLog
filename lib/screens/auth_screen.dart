import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import your new registration screen here
import 'registration_screen.dart'; 

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth(bool isSignUp) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isSignUp) {
        // This part is now handled by RegistrationScreen, 
        // but we keep the logic here just in case of direct calls.
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Success! Please check your email for a confirmation link.")),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("An unexpected error occurred.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/ironlog_logo.png',
                height: 120,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.fitness_center, size: 80, color: Colors.blue);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                "It's you vs you.",
                style: TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic),
              ),
              const Text(
                "And one of you has to die.",
                style: TextStyle(color: Colors.grey, fontSize: 16, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Email", 
                  labelStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.email, color: Colors.blue),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.lock, color: Colors.blue),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              if (_isLoading)
                const CircularProgressIndicator(color: Colors.blue)
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _handleAuth(false),
                        child: const Text("LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      // CHANGED: Now navigates to the RegistrationScreen
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                        );
                      },
                      child: const Text(
                        "Don't have an account? Create one",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_emailController.text.isNotEmpty) {
                          Supabase.instance.client.auth.resetPasswordForEmail(_emailController.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset link sent!")));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter email first")));
                        }
                      },
                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                  ],
                )
            ],
          ),
        ),
      ),
    );
  }
}