import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth_entry_screen.dart';
import '../screens/character_creation_screen.dart';
import '../screens/coin_shop_screen.dart';
import '../screens/home_dashboard_screen.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/neighborhood_hub_screen.dart';
import '../screens/phase1_integration_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/streak_recovery_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/task_detail_screen.dart';
import '../screens/task_picker_screen.dart';
import '../screens/workout_session_screen.dart';
import '../screens/workout_celebration_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  redirect: (_, state) {
    final loggedIn = FirebaseAuth.instance.currentUser != null;
    final path = state.uri.path;
    final publicRoute = path == '/splash' || path == '/auth' || path == '/login' || path == '/signup';

    if (!loggedIn && !publicRoute) {
      return '/auth';
    }
    if (loggedIn && (path == '/auth' || path == '/login' || path == '/signup')) {
      return '/splash';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/auth', builder: (_, __) => const AuthEntryScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    GoRoute(path: '/character', builder: (_, __) => const CharacterCreationScreen()),
    GoRoute(path: '/tasks', builder: (_, __) => const TaskPickerScreen()),
    GoRoute(path: '/phase1-integration', builder: (_, __) => const Phase1IntegrationScreen()),
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeDashboardScreen()),
        GoRoute(
          path: '/task-detail',
          builder: (_, state) => TaskDetailScreen(
            task: state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null,
          ),
        ),
        GoRoute(
          path: '/workout-session',
          builder: (_, state) => WorkoutSessionScreen(
            task: state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null,
          ),
        ),
        GoRoute(
          path: '/celebration',
          builder: (_, state) => WorkoutCelebrationScreen(
            payload: state.extra is Map ? Map<String, dynamic>.from(state.extra as Map) : null,
          ),
        ),
        GoRoute(path: '/leaderboard', builder: (_, __) => const LeaderboardScreen()),
        GoRoute(path: '/streak-recovery', builder: (_, __) => const StreakRecoveryScreen()),
        GoRoute(path: '/neighborhood', builder: (_, __) => const NeighborhoodHubScreen()),
        GoRoute(
          path: '/profile',
          builder: (_, state) => ProfileScreen(
            uid: state.extra is Map ? (state.extra as Map)['uid'] as String? : null,
          ),
        ),
        GoRoute(path: '/shop', builder: (_, __) => const CoinShopScreen()),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  static const _tabs = [
    '/home',
    '/leaderboard',
    '/profile',
  ];

  int _tabIndex(String location) {
    if (location.startsWith('/leaderboard')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final showBottomNav = location.startsWith('/home') || location.startsWith('/leaderboard') || location.startsWith('/profile');

    return Scaffold(
      body: child,
      bottomNavigationBar: showBottomNav
          ? BottomNavigationBar(
              currentIndex: _tabIndex(location),
              onTap: (index) => context.go(_tabs[index]),
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
                BottomNavigationBarItem(icon: Icon(Icons.leaderboard_outlined), label: 'Leaderboard'),
                BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
              ],
            )
          : null,
    );
  }
}
