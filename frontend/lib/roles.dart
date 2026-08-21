import 'package:flutter/material.dart';

import 'theme.dart';

const kWorkspaceRoles = ['admin', 'manager', 'agent', 'customer', 'guest'];

String? workspaceRole(Map? ws, String userId) {
  final members = ws?['members'] as List? ?? [];
  for (final raw in members) {
    final m = Map<String, dynamic>.from(raw as Map);
    if (m['userId'] == userId) return m['role'] as String?;
  }
  return ws?['myRole'] as String?;
}

bool canManageWorkspaceSettings(Map? ws, String userId, {String? appRole}) {
  if (appRole == 'duperadmin' || appRole == 'superadmin') return true;
  return workspaceRole(ws, userId) == 'admin';
}

bool canManageWorkspaceMembers(Map? ws, String userId, {String? appRole}) {
  if (appRole == 'duperadmin' || appRole == 'superadmin') return true;
  final role = workspaceRole(ws, userId);
  return role == 'admin' || role == 'manager';
}

bool canTriageCases(Map? ws, String userId, {String? appRole}) {
  if (appRole == 'duperadmin' || appRole == 'superadmin') return true;
  final role = workspaceRole(ws, userId);
  return role == 'admin' || role == 'manager' || role == 'agent';
}

String workspaceRoleLabel(String role) {
  switch (role) {
    case 'admin':
      return 'Admin';
    case 'manager':
      return 'Manager';
    case 'agent':
      return 'Agent';
    case 'customer':
      return 'Customer';
    case 'guest':
      return 'Guest';
    default:
      return role;
  }
}

String appRoleLabel(String? role) {
  switch (role) {
    case 'duperadmin':
      return 'DuperAdmin';
    case 'superadmin':
      return 'SuperAdmin';
    default:
      return 'User';
  }
}

const kAssignableAppRoles = ['user', 'superadmin'];

String assignableAppRoleValue(String? appRole) {
  return appRole == 'superadmin' ? 'superadmin' : 'user';
}

String userStatusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Pending';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Approved';
  }
}

Color userStatusTint(String? status) {
  switch (status) {
    case 'pending':
      return iosOrange;
    case 'rejected':
      return iosRed;
    default:
      return iosGreen;
  }
}

Color workspaceRoleTint(String role) {
  switch (role) {
    case 'admin':
      return iosPurple;
    case 'manager':
      return iosOrange;
    case 'agent':
      return iosBlue;
    case 'customer':
      return iosTeal;
    case 'guest':
      return iosGray;
    default:
      return iosGray;
  }
}

List<Map<String, dynamic>> memberMaps(Map? ws) {
  final raw = ws?['members'] as List? ?? [];
  return [for (final m in raw) Map<String, dynamic>.from(m as Map)];
}

List<String> assignableWorkspaceRoles({required bool isAppOperator}) {
  return [
    for (final r in kWorkspaceRoles)
      if (r != 'admin' || isAppOperator) r,
  ];
}

Map<String, Map<String, dynamic>> usersById(Iterable users) {
  return {
    for (final raw in users)
      (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
  };
}
