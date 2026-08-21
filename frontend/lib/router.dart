import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';
import 'paths.dart';
import 'screens/account_screen.dart';
import 'screens/add_workspace_user_screen.dart';
import 'screens/case_detail_screen.dart';
import 'screens/cases_screen.dart';
import 'screens/change_password_screen.dart';
import 'screens/cp_shell.dart';
import 'screens/login_screen.dart';
import 'screens/new_case_screen.dart';
import 'screens/new_workspace_screen.dart';
import 'screens/register_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shell.dart';
import 'screens/cp_new_user_screen.dart';
import 'screens/usermaster_screen.dart';
import 'screens/users_screen.dart';
import 'screens/workspace_index.dart';
import 'screens/workspace_picker_screen.dart';
import 'theme.dart';
import 'workspace_store.dart';

Page<void> _page(GoRouterState state, Widget child) => NoTransitionPage<void>(
      key: state.pageKey,
      child: child,
    );

GoRouter createRouter(AuthState auth, WorkspaceStore workspaces) {
  return GoRouter(
    initialLocation: '/wspace',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggingIn = loc == '/login' || loc == '/register';
      if (auth.loading) return null;
      if (!auth.isLoggedIn) return loggingIn ? null : '/login';
      if (auth.mustChange && loc != '/change-password') return '/change-password';
      if (loggingIn) {
        return defaultHomeAfterLogin(
          isAppOperator: auth.isAppOperator,
          firstWorkspaceId: workspaces.workspaces.isNotEmpty ? workspaces.workspaces.first['id'] as String? : null,
        );
      }
      if (loc.startsWith('/cp') && !auth.isAppOperator) {
        final first = workspaces.workspaces.isNotEmpty ? workspaces.workspaces.first['id'] as String? : null;
        return first != null ? wspaceCases(first) : '/wspace';
      }
      if (loc == '/cp') return cpWorkspaces;
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _page(state, const LoginScreen()),
      ),
      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => _page(state, const RegisterScreen()),
      ),
      GoRoute(
        path: '/change-password',
        pageBuilder: (context, state) => _page(state, const ChangePasswordScreen()),
      ),
      GoRoute(
        path: '/wspace',
        pageBuilder: (context, state) => _page(state, const WorkspacePickerScreen()),
      ),
      ShellRoute(
        builder: (context, state, child) => CpShell(child: child),
        routes: [
          GoRoute(
            path: '/cp/workspace',
            pageBuilder: (context, state) => _page(state, const WorkspaceIndex()),
          ),
          GoRoute(
            path: '/cp/workspace/new',
            pageBuilder: (context, state) => _page(state, const NewWorkspaceScreen()),
          ),
          GoRoute(
            path: '/cp/users',
            pageBuilder: (context, state) => _page(state, const UsermasterScreen()),
          ),
          GoRoute(
            path: '/cp/users/new',
            pageBuilder: (context, state) => _page(state, const CpNewUserScreen()),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) {
          final wid = state.pathParameters['workspaceId'] ?? '';
          return AppShell(workspaceId: wid, child: child);
        },
        routes: [
          GoRoute(
            path: '/wspace/:workspaceId/app/cases',
            pageBuilder: (context, state) => _page(
              state,
              CasesScreen(workspaceId: state.pathParameters['workspaceId']!),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/cases/new',
            pageBuilder: (context, state) => _page(
              state,
              NewCaseScreen(workspaceId: state.pathParameters['workspaceId']!),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/cases/:caseId',
            pageBuilder: (context, state) => _page(
              state,
              CaseDetailScreen(
                workspaceId: state.pathParameters['workspaceId']!,
                id: state.pathParameters['caseId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/users/add',
            pageBuilder: (context, state) => _page(
              state,
              AddWorkspaceUserScreen(workspaceId: state.pathParameters['workspaceId']!),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/users',
            pageBuilder: (context, state) => _page(
              state,
              UsersScreen(workspaceId: state.pathParameters['workspaceId']!),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/settings',
            pageBuilder: (context, state) => _page(
              state,
              SettingsScreen(workspaceId: state.pathParameters['workspaceId']!),
            ),
          ),
          GoRoute(
            path: '/wspace/:workspaceId/app/you',
            pageBuilder: (context, state) => _page(state, const AccountScreen()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const Scaffold(
      body: Center(child: Text('Not found', style: TextStyle(color: iosSecondary))),
    ),
  );
}
