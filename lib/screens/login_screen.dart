import 'package:auth_app/providers/auth_provider.dart';
import 'package:auth_app/widgets/widgets.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Color(0xFF6200EE)),
                  const SizedBox(height: 32),
                  const Text(
                    'Bienvenido de nuevo',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inicia sesión para continuar',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  const _LoginForm(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes una cuenta?',
                        style: TextStyle(color: Colors.grey),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/register');
                        },
                        child: const Text(
                          'Regístrate',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su correo';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Por favor ingrese un correo válido';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Por favor ingrese su contraseña';
    }
    if (value.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(authProvider.notifier)
          .login(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    if (authState.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(authProvider.notifier).resetError();
      });
    }

    if (authState.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Inicio de sesión exitoso!'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/home');
      });
    }

    return Form(
      key: _formKey,
      child: Column(
        children: [
          CustomTextField(
            label: 'Correo electrónico',
            prefixIcon: Icons.email_outlined,
            controller: _emailController,
            validator: _validateEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            label: 'Contraseña',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            controller: _passwordController,
            validator: _validatePassword,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showForgotPasswordModal(context, ref),
              child: const Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CustomButton(
            text: 'Iniciar sesión',
            onPressed: _submitForm,
            isLoading: authState.isLoading,
          ),
        ],
      ),
    );
  }
}

void _showForgotPasswordModal(BuildContext context, WidgetRef ref) {
  final forgotPasswordEmailController = TextEditingController();
  final authState = ref.watch(authProvider);
  if (authState.errorMessage != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
      ref.read(authProvider.notifier).resetError();
    });
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final authState = ref.watch(authProvider);
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16.0,
          right: 16.0,
          top: 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Restablecer Contraseña',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20.0),
            TextField(
              controller: forgotPasswordEmailController,
              decoration: const InputDecoration(
                labelText: 'Ingresa tu correo electrónico',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 20.0),
            ElevatedButton(
              onPressed: () async {
                if (!authState.isLoading) {
                  final resp = await ref
                      .read(authProvider.notifier)
                      .resetPassword(forgotPasswordEmailController.text.trim());
                  if (resp) {
                    context.pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Se ha enviado un enlace de restablecimiento a ${forgotPasswordEmailController.text}",
                          ),
                          backgroundColor: Colors.white,
                        ),
                      );
                      ref.read(authProvider.notifier).resetError();
                    });
                  }
                }
              },
              child:
                  authState.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Enviar enlace de restablecimiento'),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      );
    },
  );
}
