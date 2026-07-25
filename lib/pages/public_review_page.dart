import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/public_review_ticket.dart';
import '../services/public_review_service.dart';

/// Pagina publica de resena (sin sesion), D-058 / sub-bloque 1 de
/// "Resenas y fotos de trabajo". Se llega aqui via "?resena=`ticket_id`"
/// (ver main.dart), igual patron que PublicBookingPage con "?reservar=".
class PublicReviewPage extends StatefulWidget {
  const PublicReviewPage({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<PublicReviewPage> createState() => _PublicReviewPageState();
}

class _PublicReviewPageState extends State<PublicReviewPage> {
  final PublicReviewService reviewService = const PublicReviewService();
  final commentController = TextEditingController();

  bool isLoading = true;
  String? loadError;
  PublicReviewTicket? ticket;

  int selectedRating = 0;
  PublicReviewServiceOption? selectedOption;

  bool isSubmitting = false;
  String? submitError;
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    _loadTicket();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTicket() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final loaded = await reviewService.getTicketForReview(widget.ticketId);
      if (!mounted) return;
      setState(() {
        ticket = loaded;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadError = _friendlyError(error);
        isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (selectedRating < 1) {
      setState(() {
        submitError = 'Selecciona una calificacion de 1 a 5 estrellas.';
      });
      return;
    }

    setState(() {
      isSubmitting = true;
      submitError = null;
    });

    try {
      await reviewService.createReview(
        ticketId: widget.ticketId,
        rating: selectedRating,
        comment: commentController.text.trim().isEmpty
            ? null
            : commentController.text.trim(),
        stylistId: selectedOption?.stylistId,
        serviceId: selectedOption?.serviceId,
      );

      if (!mounted) return;
      setState(() {
        submitted = true;
        isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        submitError = _friendlyError(error);
        isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5FF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (loadError != null) {
      return _MessageCard(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        message: loadError!,
      );
    }

    final loadedTicket = ticket!;

    if (submitted) {
      return const _MessageCard(
        icon: Icons.check_circle_outline,
        iconColor: Color(0xFF059669),
        message: 'Gracias por tu opinion. Tu resena quedara publicada '
            'despues de ser revisada por el negocio.',
      );
    }

    if (loadedTicket.alreadyReviewed) {
      return const _MessageCard(
        icon: Icons.info_outline,
        iconColor: Color(0xFF6B7280),
        message: 'Ya se registro una resena para esta visita. Gracias.',
      );
    }

    if (!loadedTicket.reviewable) {
      return const _MessageCard(
        icon: Icons.hourglass_empty_outlined,
        iconColor: Color(0xFF6B7280),
        message: 'Esta visita todavia no ha finalizado. Cuando el negocio '
            'la marque como finalizada podras dejar tu resena.',
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loadedTicket.branchName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D1B69),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Hola ${loadedTicket.clientName}, cuentanos como te fue.',
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Calificacion',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final filled = starValue <= selectedRating;
                return IconButton(
                  onPressed: () {
                    setState(() {
                      selectedRating = starValue;
                      submitError = null;
                    });
                  },
                  icon: Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: const Color(0xFFF59E0B),
                    size: 32,
                  ),
                );
              }),
            ),
            if (loadedTicket.services.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Servicio (opcional)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PublicReviewServiceOption>(
                initialValue: selectedOption,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Sin especificar'),
                items: loadedTicket.services
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(
                          option.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedOption = value;
                  });
                },
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Comentario (opcional)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Cuentanos tu experiencia...',
              ),
            ),
            if (submitError != null) ...[
              const SizedBox(height: 16),
              Text(
                submitError!,
                style: const TextStyle(color: Color(0xFFB91C1C)),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar resena'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.iconColor,
    required this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
            ),
          ],
        ),
      ),
    );
  }
}

String _friendlyError(Object error) {
  if (error is PostgrestException) {
    return error.message;
  }
  return error.toString();
}
