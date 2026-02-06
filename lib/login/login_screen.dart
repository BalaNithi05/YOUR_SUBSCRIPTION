import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/home_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'reset_password_screen.dart';
import '../services/currency_service.dart';
import '../services/theme_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final StreamSubscription<AuthState> _authSubscription;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // 🔥 Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // 🔐 AUTH STATE LISTENER
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      if (!mounted) return;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
        );
        return;
      }

      if (data.event == AuthChangeEvent.signedIn) {
        await _handleUserAfterLogin();
      }
    });
  }

  // =====================================================
  // 🔥 CREATE PROFILE IF NOT EXISTS
  // =====================================================
  Future<void> _handleUserAfterLogin() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    try {
      // 🔎 Check if profile exists
      final existingProfile = await client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      // 🆕 Create profile if not exists
      if (existingProfile == null) {
        await client.from('profiles').insert({
          'id': user.id,
          'name':
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              'User',
          'email': user.email,
          'currency': 'INR',
          'theme_mode': 'system',
          'plan': 'free',
        });
      }

      // 🔄 Load user settings
      await ThemeService.loadUserTheme();
      await CurrencyService.loadUserCurrency();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint("Login setup error: $e");
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _controller.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =====================================================
  // 🔵 GOOGLE LOGIN
  // =====================================================
  Future<void> loginWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback',
    );
  }

  // =====================================================
  // 📧 EMAIL LOGIN
  // =====================================================
  Future<void> loginWithEmail() async {
    setState(() => isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (response.user != null && response.user!.emailConfirmedAt == null) {
        await Supabase.instance.client.auth.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please verify your email before logging in."),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => isLoading = false);
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌈 Background
          AnimatedContainer(
            duration: const Duration(seconds: 5),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 30,
                        color: Colors.black.withOpacity(0.2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.subscriptions,
                          size: 60,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 20),

                        const Text(
                          "Welcome Back",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 24),

                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscurePassword = !obscurePassword;
                                });
                              },
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text("Forgot password?"),
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : loginWithEmail,
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : const Text("Login"),
                          ),
                        ),

                        const SizedBox(height: 16),
                        const Text("OR"),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text("Continue with Google"),
                            onPressed: loginWithGoogle,
                          ),
                        ),

                        const SizedBox(height: 24),

                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text("Create new account"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
