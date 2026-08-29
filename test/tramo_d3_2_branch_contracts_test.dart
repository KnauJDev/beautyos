import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salonymas/pages/dashboard_page.dart';
import 'package:salonymas/pages/my_stylist_work_photos_page.dart';
import 'package:salonymas/pages/reviews_page.dart';
import 'package:salonymas/pages/settings_page.dart';
import 'package:salonymas/pages/work_photos_page.dart';
import 'package:salonymas/services/appointment_policy_service.dart';
import 'package:salonymas/services/business_hours_service.dart';
import 'package:salonymas/services/dashboard_service.dart';
import 'package:salonymas/services/my_stylist_work_photos_service.dart';
import 'package:salonymas/services/reviews_service.dart';
import 'package:salonymas/services/work_photos_service.dart';

void main() {
  const branchId = 'branch-a2';

  test('los seis servicios exigen y conservan la sede seleccionada', () {
    expect(const DashboardService(branchId: branchId).branchId, branchId);
    expect(const BusinessHoursService(branchId: branchId).branchId, branchId);
    expect(
      const AppointmentPolicyService(branchId: branchId).branchId,
      branchId,
    );
    expect(const WorkPhotosService(branchId: branchId).branchId, branchId);
    expect(const ReviewsService(branchId: branchId).branchId, branchId);
    expect(
      const MyStylistWorkPhotosService(branchId: branchId).branchId,
      branchId,
    );
  });

  test('las cinco superficies conservan sede y clave de reconstruccion', () {
    final pages = <Widget>[
      const DashboardPage(
        key: ValueKey('dashboard-branch-a2'),
        branchId: branchId,
        nombreParaSaludo: 'Carlos',
      ),
      const MyStylistWorkPhotosPage(
        key: ValueKey('my-photos-branch-a2'),
        branchId: branchId,
      ),
      const FotosTrabajosPage(
        key: ValueKey('work-photos-branch-a2'),
        branchId: branchId,
      ),
      const ResenasPage(key: ValueKey('reviews-branch-a2'), branchId: branchId),
      const ConfiguracionPage(
        key: ValueKey('settings-branch-a2'),
        branchId: branchId,
        isOwner: true,
      ),
    ];

    expect(
      pages.map((page) => page.key),
      everyElement(isA<ValueKey<String>>()),
    );
    expect((pages[0] as DashboardPage).branchId, branchId);
    expect((pages[1] as MyStylistWorkPhotosPage).branchId, branchId);
    expect((pages[2] as FotosTrabajosPage).branchId, branchId);
    expect((pages[3] as ResenasPage).branchId, branchId);
    expect((pages[4] as ConfiguracionPage).branchId, branchId);
  });
}
