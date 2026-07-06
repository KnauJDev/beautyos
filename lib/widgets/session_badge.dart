import 'package:flutter/material.dart';

import '../models/my_profile.dart';
import '../services/my_profile_service.dart';

class SessionBadge extends StatefulWidget {
  const SessionBadge({super.key});

  @override
  State<SessionBadge> createState() => _SessionBadgeState();
}

class _SessionBadgeState extends State<SessionBadge> {
  final MyProfileService myProfileService = const MyProfileService();

  late final Future<MyProfile?> profileFuture;

  @override
  void initState() {
    super.initState();
    profileFuture = myProfileService.getMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyProfile?>(
      future: profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null) {
          return const Text(
            'Usuario',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  profile.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${profile.roleText} · ${profile.tenantName ?? 'Sin negocio'}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFEDE9FE),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
