class UserBranchAccess {
  const UserBranchAccess({
    required this.branchId,
    required this.branchName,
    required this.isPrimary,
    required this.hasAccess,
    this.inCatalog,
  });

  final String branchId;
  final String branchName;
  final bool isPrimary;
  final bool hasAccess;
  final bool? inCatalog;

  factory UserBranchAccess.fromMap(Map<String, dynamic> map) {
    return UserBranchAccess(
      branchId: map['branch_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      isPrimary: map['is_primary'] == true,
      hasAccess: map['has_access'] == true,
      inCatalog: map['in_catalog'] == null ? null : map['in_catalog'] == true,
    );
  }

  UserBranchAccess copyWith({
    String? branchId,
    String? branchName,
    bool? isPrimary,
    bool? hasAccess,
    bool? inCatalog,
  }) {
    return UserBranchAccess(
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      isPrimary: isPrimary ?? this.isPrimary,
      hasAccess: hasAccess ?? this.hasAccess,
      inCatalog: inCatalog ?? this.inCatalog,
    );
  }
}
