import 'package:auth_app/interfaces/task_interface.dart';
import 'package:auth_app/screens/screens.dart';

import 'package:go_router/go_router.dart';

final routes = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => RegisterScreen()),
    GoRoute(path: '/home', builder: (context, state) => HomeScreen()),
    GoRoute(
      path: '/task-detail',
      builder: (context, state) {
        final Task? task = state.extra as Task?;
        return TaskDetailScreen(task: task!);
      },
    ),
  ],
);
