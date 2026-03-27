import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/supabase_config.dart';
import '../../../core/theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseConfig.getClient().auth.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            data: {
              'full_name': _fullNameController.text.trim(),
              'phone': _phoneController.text.trim(),
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign up successful! Please check your email.'),
          ),
        );
        Navigator.of(context).pushNamed('/login');
      }
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
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Join us today',
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
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      hintText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outlined),
                    ),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16.0),
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
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      hintText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
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
                    onPressed: _isLoading ? null : _signup,
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
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () => Navigator.of(context).pushNamed('/login'),
                        child: Text(
                          'Sign In',
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
