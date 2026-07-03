class DashboardMetrics {
  final int activeServicesCount;
  final int clientsCount;
  final int confirmedTicketsCount;
  final int todayTicketsCount;
  final int activeStylistsCount;
  final int activeStylistServicesCount;

  const DashboardMetrics({
    required this.activeServicesCount,
    required this.clientsCount,
    required this.confirmedTicketsCount,
    required this.todayTicketsCount,
    required this.activeStylistsCount,
    required this.activeStylistServicesCount,
  });

  factory DashboardMetrics.fromMap(Map<String, dynamic> map) {
    return DashboardMetrics(
      activeServicesCount: map['active_services_count'] as int? ?? 0,
      clientsCount: map['clients_count'] as int? ?? 0,
      confirmedTicketsCount: map['confirmed_tickets_count'] as int? ?? 0,
      todayTicketsCount: map['today_tickets_count'] as int? ?? 0,
      activeStylistsCount: map['active_stylists_count'] as int? ?? 0,
      activeStylistServicesCount:
          map['active_stylist_services_count'] as int? ?? 0,
    );
  }
}
