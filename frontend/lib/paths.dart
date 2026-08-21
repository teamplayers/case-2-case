import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Control panel paths (no workspace in URL).
const cpHome = '/cp/workspace';
const cpWorkspaces = '/cp/workspace';
const cpWorkspaceNew = '/cp/workspace/new';
const cpUsers = '/cp/users';
const cpUsersNew = '/cp/users/new';

String cpPath(String section) => '/cp/$section';

/// Workspace app paths: /wspace/<id>/app/<feature>
String wspacePath(String workspaceId, String feature) => '/wspace/$workspaceId/app/$feature';

String wspaceCases(String workspaceId) => wspacePath(workspaceId, 'cases');
String wspaceCase(String workspaceId, String caseId) => '${wspaceCases(workspaceId)}/$caseId';
String wspaceNewCase(String workspaceId) => wspacePath(workspaceId, 'cases/new');
String wspaceUsers(String workspaceId) => wspacePath(workspaceId, 'users');
String wspaceAddUser(String workspaceId) => wspacePath(workspaceId, 'users/add');
String wspaceSettings(String workspaceId) => wspacePath(workspaceId, 'settings');
String wspaceYou(String workspaceId) => wspacePath(workspaceId, 'you');

String? workspaceIdFromLocation(String location) {
  final segs = Uri.parse(location).pathSegments;
  if (segs.length >= 2 && segs[0] == 'wspace') return segs[1];
  return null;
}

String? workspaceFeatureFromLocation(String location) {
  final segs = Uri.parse(location).pathSegments;
  if (segs.length >= 4 && segs[0] == 'wspace' && segs[2] == 'app') {
    return segs.sublist(3).join('/');
  }
  return null;
}

void switchWorkspace(BuildContext context, String newId) {
  final feature = workspaceFeatureFromLocation(GoRouterState.of(context).uri.path);
  if (feature != null && feature.isNotEmpty) {
    context.go(wspacePath(newId, feature));
  } else {
    context.go(wspaceCases(newId));
  }
}

String defaultHomeAfterLogin({required bool isAppOperator, String? firstWorkspaceId}) {
  if (isAppOperator) return cpWorkspaces;
  if (firstWorkspaceId != null) return wspaceCases(firstWorkspaceId);
  return '/wspace';
}
