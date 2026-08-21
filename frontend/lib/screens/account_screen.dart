import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_state.dart';
import '../paths.dart';
import '../roles.dart';
import '../theme.dart';
import '../widgets.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final initial = auth.name.isNotEmpty
        ? auth.name[0].toUpperCase()
        : auth.username.isNotEmpty
            ? auth.username[0].toUpperCase()
            : '?';
    final badge = auth.isAppOperator ? appRoleLabel(auth.appRole) : appRoleLabel(null);
    return SafeArea(
      child: ContentWidth(
        child: ListView(
          children: [
            const LargeTitle('You'),
            const SizedBox(height: 8),
            Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: iosBlue.withValues(alpha: 0.12),
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: iosBlue),
                  ),
                ),
                const SizedBox(height: 12),
                Text(auth.name.isNotEmpty ? auth.name : auth.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(auth.email, style: const TextStyle(fontSize: 15, color: iosSecondary)),
                const SizedBox(height: 8),
                IosBadge(badge, color: iosBlue),
              ],
            ),
            const SizedBox(height: 28),
            if (auth.isAppOperator)
              InsetGroup(
                header: 'Platform',
                children: [
                  IosCell(
                    leading: const Icon(CupertinoIcons.person_3, size: 20, color: iosBlue),
                    title: 'User master',
                    chevron: true,
                    onTap: () => context.go(cpUsers),
                  ),
                ],
              ),
            InsetGroup(
              header: 'Account',
              children: [
                IosCell(
                  leading: const Icon(CupertinoIcons.lock, size: 20, color: iosBlue),
                  title: 'Change password',
                  chevron: true,
                  onTap: () => context.push('/change-password'),
                ),
              ],
            ),
            InsetGroup(
              children: [
                IosCell(
                  leading: const Icon(CupertinoIcons.square_arrow_right, size: 20, color: iosRed),
                  title: 'Sign out',
                  destructive: true,
                  onTap: () => auth.logout(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
