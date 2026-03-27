import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import '../../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.getClient().auth.signInWithPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      setState(() {
        _errorMessage = error.message;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[400],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32.0),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.red[900],
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                  ],
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      hintText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16.0),
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      prefixIcon: Icon(Icons.lock_outlined),
                    ),
                    obscureText: true,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 32.0),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20.0,
                            width: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).pushNamed('/signup'),
                        child: Text(
                          'Sign Up',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
