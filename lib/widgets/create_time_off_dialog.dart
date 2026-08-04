import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/stylist_time_off_service.dart';

/// Dialogo para que el estilista bloquee un rango de su propia agenda
/// (vacaciones, incapacidad, etc.). El dueno/admin usa el mismo servicio
/// desde otra pantalla si necesitan hacerlo por el estilista.
class CreateTimeOffDialog extends StatefulWidget {
  const CreateTimeOffDialog({super.key, required this.branchId});

  final String branchId;

  @override
  State<CreateTimeOffDialog> createState() => _CreateTimeOffDialogState();
}

class _CreateTimeOffDialogState extends State<CreateTimeOffDialog> {
  late final StylistTimeOffService _service;
  final _reasonController = TextEditingController();

  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _repeats = false;
  String _repeatFrequency = 'daily';
  DateTime? _repeatUntil;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = StylistTimeOffService(branchId: widget.branchId);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );

    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay(hour: initial.hour, minute: initial.minute)
          : const TimeOfDay(hour: 8, minute: 0),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart() async {
    final picked = await _pickDateTime(_startsAt);
    if (picked != null) {
      setState(() => _startsAt = picked);
    }
  }

  Future<void> _pickEnd() async {
    final picked = await _pickDateTime(_endsAt ?? _startsAt);
    if (picked != null) {
      setState(() => _endsAt = picked);
    }
  }

  Future<void> _pickRepeatUntil() async {
    final now = DateTime.now();
    final base = _startsAt ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? base,
      firstDate: base,
      lastDate: base.add(const Duration(days: 180)),
    );

    if (picked != null) {
      setState(() => _repeatUntil = picked);
    }
  }

  Future<void> _save() async {
    final startsAt = _startsAt;
    final endsAt = _endsAt;

    if (startsAt == null || endsAt == null) {
      setState(() => _error = 'Selecciona el inicio y el fin del bloqueo.');
      return;
    }

    if (!endsAt.isAfter(startsAt)) {
      setState(() => _error = 'El fin debe ser posterior al inicio.');
      return;
    }

    if (_repeats && _repeatUntil == null) {
      setState(() => _error = 'Selecciona hasta qué fecha se repite.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _service.createTimeOff(
        startsAt: startsAt,
        endsAt: endsAt,
        reason: _reasonController.text.trim().isEmpty
            ? null
            : _reasonController.text.trim(),
        repeatFrequency: _repeats ? _repeatFrequency : null,
        repeatUntil: _repeats ? _repeatUntil : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PostgrestException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Ocurrió un error inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _formatPicked(DateTime? value) {
    if (value == null) return 'Seleccionar';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day/$month/${value.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bloquear mi agenda'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ese rango dejará de aparecer como disponible para citas '
              'nuevas en todas tus sedes.',
              style: TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickStart,
              icon: const Icon(Icons.event_outlined),
              label: Text('Desde: ${_formatPicked(_startsAt)}'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickEnd,
              icon: const Icon(Icons.event_available_outlined),
              label: Text('Hasta: ${_formatPicked(_endsAt)}'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Repetir este bloqueo'),
              value: _repeats,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _repeats = value),
            ),
            if (_repeats) ...[
              DropdownButtonFormField<String>(
                initialValue: _repeatFrequency,
                decoration: const InputDecoration(labelText: 'Frecuencia'),
                items: const [
                  DropdownMenuItem(value: 'daily', child: Text('Diariamente')),
                  DropdownMenuItem(
                    value: 'weekly',
                    child: Text('Semanalmente'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _repeatFrequency = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : _pickRepeatUntil,
                icon: const Icon(Icons.event_repeat_outlined),
                label: Text('Hasta el: ${_formatPicked(_repeatUntil)}'),
              ),
              const SizedBox(height: 4),
              const Text(
                'Máximo 180 días de repetición.',
                style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Bloquear'),
        ),
      ],
    );
  }
}
