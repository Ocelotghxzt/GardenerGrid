import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final err = await context.read<AuthProvider>()
        .signIn(_email.text.trim(), _password.text);
    if (mounted) {
      setState(() { _loading = false; _error = err; });
      if (err == null) context.go('/home');
    }
  }

  Future<void> _showReset() async {
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reset password'),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          actions: [
            TextButton(
              onPressed: () => ctx.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => ctx.pop(ctrl.text.trim()),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
    if (email != null && email.contains('@')) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final messenger = ScaffoldMessenger.of(context);
      final err = await auth.resetPassword(email);
      if (!mounted) return;
      final msg = err == null ? 'Reset email sent!' : 'Could not send: $err';
      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.primary,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.grass, size: 72, color: AppTheme.primary),
                const SizedBox(height: 8),
                Text('GardenerGrid',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppTheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Grow smarter, earn more.',
                    style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 40),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                            labelText: 'Email', prefixIcon: Icon(Icons.email)),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) =>
                            v!.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        decoration: const InputDecoration(
                            labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                        obscureText: true,
                        validator: (v) =>
                            v!.length >= 6 ? null : 'Minimum 6 characters',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppTheme.error)),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _showReset,
                        child: const Text('Forgot password?'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.go('/register'),
                        child: const Text("Don't have an account? Register"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
