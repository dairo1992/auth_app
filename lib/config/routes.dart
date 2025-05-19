
import 'package:go_router/go_router.dart';
import 'package:kanban_board_app/interfaces/task_interface.dart';
import 'package:kanban_board_app/screens/screens.dart';


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
