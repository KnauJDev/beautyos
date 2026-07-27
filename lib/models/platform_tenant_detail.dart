class PlatformClientSummary {
  const PlatformClientSummary({
    required this.clientId,
    required this.name,
    required this.phone,
    required this.email,
    required this.active,
    required this.createdAt,
  });

  final String clientId;
  final String name;
  final String? phone;
  final String? email;
  final bool active;
  final DateTime? createdAt;

  factory PlatformClientSummary.fromMap(Map<String, dynamic> map) {
    return PlatformClientSummary(
      clientId: map['client_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Sin nombre',
      phone: map['phone']?.toString(),
      email: map['email']?.toString(),
      active: map['active'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }
}

class PlatformTicketSummary {
  const PlatformTicketSummary({
    required this.ticketId,
    required this.branchName,
    required this.clientName,
    required this.scheduledAt,
    required this.status,
    required this.serviceNames,
    required this.stylistNames,
    required this.totalPrice,
    required this.paidAmount,
  });

  final String ticketId;
  final String branchName;
  final String clientName;
  final DateTime? scheduledAt;
  final String status;
  final String serviceNames;
  final String stylistNames;
  final double totalPrice;
  final double paidAmount;

  factory PlatformTicketSummary.fromMap(Map<String, dynamic> map) {
    return PlatformTicketSummary(
      ticketId: map['ticket_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      clientName: map['client_name']?.toString() ?? 'Cliente sin nombre',
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.tryParse(map['scheduled_at'].toString())?.toLocal(),
      status: map['status']?.toString() ?? '',
      serviceNames: map['service_names']?.toString() ?? 'Sin servicios',
      stylistNames: map['stylist_names']?.toString() ?? 'Sin estilista',
      totalPrice: _readDouble(map['total_price']),
      paidAmount: _readDouble(map['paid_amount']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PlatformBranchFinancialSummary {
  const PlatformBranchFinancialSummary({
    required this.branchId,
    required this.branchName,
    required this.totalSales,
    required this.totalPurchases,
    required this.totalExpenses,
    required this.totalCommissions,
    required this.netResult,
  });

  final String branchId;
  final String branchName;
  final double totalSales;
  final double totalPurchases;
  final double totalExpenses;
  final double totalCommissions;
  final double netResult;

  factory PlatformBranchFinancialSummary.fromMap(Map<String, dynamic> map) {
    return PlatformBranchFinancialSummary(
      branchId: map['branch_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      totalSales: _readDouble(map['total_sales']),
      totalPurchases: _readDouble(map['total_purchases']),
      totalExpenses: _readDouble(map['total_expenses']),
      totalCommissions: _readDouble(map['total_commissions']),
      netResult: _readDouble(map['net_result']),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class PlatformTeamMember {
  const PlatformTeamMember({
    required this.profileId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.active,
    required this.stylistName,
  });

  final String profileId;
  final String fullName;
  final String email;
  final String role;
  final bool active;
  final String? stylistName;

  factory PlatformTeamMember.fromMap(Map<String, dynamic> map) {
    return PlatformTeamMember(
      profileId: map['profile_id']?.toString() ?? '',
      fullName: map['full_name']?.toString() ?? 'Sin nombre',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      active: map['active'] == true,
      stylistName: map['stylist_name']?.toString(),
    );
  }
}

class PlatformReviewSummary {
  const PlatformReviewSummary({
    required this.reviewId,
    required this.branchName,
    required this.clientName,
    required this.stylistName,
    required this.serviceName,
    required this.rating,
    required this.comment,
    required this.moderationStatus,
    required this.visibleToPublic,
  });

  final String reviewId;
  final String branchName;
  final String clientName;
  final String stylistName;
  final String serviceName;
  final int rating;
  final String? comment;
  final String moderationStatus;
  final bool visibleToPublic;

  factory PlatformReviewSummary.fromMap(Map<String, dynamic> map) {
    return PlatformReviewSummary(
      reviewId: map['review_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      clientName: map['client_name']?.toString() ?? 'Cliente no asociado',
      stylistName: map['stylist_name']?.toString() ?? 'Estilista no asociado',
      serviceName: map['service_name']?.toString() ?? 'Servicio no asociado',
      rating: map['rating'] is int
          ? map['rating'] as int
          : int.tryParse(map['rating']?.toString() ?? '') ?? 0,
      comment: map['comment']?.toString(),
      moderationStatus: map['moderation_status']?.toString() ?? '',
      visibleToPublic: map['visible_to_public'] == true,
    );
  }
}

class PlatformWorkPhotoSummary {
  const PlatformWorkPhotoSummary({
    required this.photoId,
    required this.branchName,
    required this.clientName,
    required this.stylistName,
    required this.photoUrl,
    required this.photoType,
    required this.visibleToCustomer,
    required this.approvedForPortfolio,
  });

  final String photoId;
  final String branchName;
  final String clientName;
  final String stylistName;
  final String photoUrl;
  final String photoType;
  final bool visibleToCustomer;
  final bool approvedForPortfolio;

  factory PlatformWorkPhotoSummary.fromMap(Map<String, dynamic> map) {
    return PlatformWorkPhotoSummary(
      photoId: map['photo_id']?.toString() ?? '',
      branchName: map['branch_name']?.toString() ?? 'Sede',
      clientName: map['client_name']?.toString() ?? 'Cliente no asociado',
      stylistName: map['stylist_name']?.toString() ?? 'Estilista no asociado',
      photoUrl: map['photo_url']?.toString() ?? '',
      photoType: map['photo_type']?.toString() ?? '',
      visibleToCustomer: map['visible_to_customer'] == true,
      approvedForPortfolio: map['approved_for_portfolio'] == true,
    );
  }
}
