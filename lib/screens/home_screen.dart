import 'package:auth_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hola, ${authState.user!.userMetadata!['name'].toString().toUpperCase()}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              context.go('/');
            },
            icon: Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: const Center(child: Text('Home Screen')),
    );
  }
}
