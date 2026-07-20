import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beautyos/pages/dashboard_page.dart';
import 'package:beautyos/pages/my_stylist_work_photos_page.dart';
import 'package:beautyos/pages/reviews_page.dart';
import 'package:beautyos/pages/settings_page.dart';
import 'package:beautyos/pages/work_photos_page.dart';
import 'package:beautyos/services/appointment_policy_service.dart';
import 'package:beautyos/services/business_hours_service.dart';
import 'package:beautyos/services/dashboard_service.dart';
import 'package:beautyos/services/my_stylist_work_photos_service.dart';
import 'package:beautyos/services/reviews_service.dart';
import 'package:beautyos/services/work_photos_service.dart';

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
