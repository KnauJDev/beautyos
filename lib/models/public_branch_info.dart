class PublicBranchInfo {
  const PublicBranchInfo({
    required this.branchId,
    required this.tenantId,
    required this.businessName,
    required this.branchName,
    required this.address,
    required this.city,
    required this.whatsapp,
    required this.timezone,
    required this.currencyCode,
    this.logoUrl,
    this.coverPhotoUrl,
  });

  final String branchId;
  final String tenantId;
  final String businessName;
  final String branchName;
  final String? address;
  final String? city;
  final String? whatsapp;
  final String timezone;
  final String currencyCode;
  final String? logoUrl;
  final String? coverPhotoUrl;

  factory PublicBranchInfo.fromMap(Map<String, dynamic> map) {
    return PublicBranchInfo(
      branchId: map['branch_id'].toString(),
      tenantId: map['tenant_id'].toString(),
      businessName: map['business_name']?.toString() ?? 'Este negocio',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      address: map['address']?.toString(),
      city: map['city']?.toString(),
      whatsapp: map['whatsapp']?.toString(),
      timezone: map['timezone']?.toString() ?? 'America/Bogota',
      currencyCode: map['currency_code']?.toString() ?? 'COP',
      logoUrl: map['logo_url']?.toString(),
      coverPhotoUrl: map['cover_photo_url']?.toString(),
    );
  }
}
