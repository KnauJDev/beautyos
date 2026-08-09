import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/ticket_service_management_item.dart';
import '../services/work_photos_service.dart';
import '../services/work_photos_upload_service.dart';

/// Dialogo para agregar una foto de trabajo a un ticket, usado tanto por
/// `TicketsPage` (admin/owner, puede atribuir a un estilista del ticket)
/// como por `MyStylistAgendaPage` (estilista, siempre se autoatribuye
/// -- por eso [stylistOptions] es opcional y nulo en ese caso).
class AddWorkPhotoDialog extends StatefulWidget {
  const AddWorkPhotoDialog({
    super.key,
    required this.branchId,
    required this.ticketId,
    this.stylistOptions,
  });

  final String branchId;
  final String ticketId;
  final List<TicketServiceManagementItem>? stylistOptions;

  @override
  State<AddWorkPhotoDialog> createState() => _AddWorkPhotoDialogState();
}

class _AddWorkPhotoDialogState extends State<AddWorkPhotoDialog> {
  final _uploadService = const WorkPhotosUploadService();
  late final WorkPhotosService _workPhotosService;
  final _captionController = TextEditingController();

  String _photoType = 'before';
  String? _selectedStylistId;
  XFile? _pickedImage;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _workPhotosService = WorkPhotosService(branchId: widget.branchId);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _uploadService.pickImage();
    if (image == null) return;
    setState(() {
      _pickedImage = image;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final image = _pickedImage;
    if (image == null) {
      setState(() {
        _error = 'Selecciona una foto para subir.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Sube al almacen privado y devuelve la RUTA, no una direccion: la
      // foto todavia no es publica y no debe tener direccion publica (H-09).
      final storagePath = await _uploadService.uploadWorkPhoto(
        branchId: widget.branchId,
        image: image,
      );

      await _workPhotosService.createWorkPhoto(
        ticketId: widget.ticketId,
        storagePath: storagePath,
        photoType: _photoType,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        stylistId: _selectedStylistId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      setState(() {
        _error = message;
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stylistOptions = widget.stylistOptions;

    return AlertDialog(
      title: const Text('Agregar foto de trabajo'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _photoType,
                decoration: const InputDecoration(labelText: 'Tipo de foto'),
                items: const [
                  DropdownMenuItem(value: 'before', child: Text('Antes')),
                  DropdownMenuItem(value: 'after', child: Text('Despues')),
                  DropdownMenuItem(value: 'final', child: Text('Final')),
                  DropdownMenuItem(
                    value: 'portfolio',
                    child: Text('Portafolio'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _photoType = value;
                    });
                  }
                },
              ),
              if (stylistOptions != null && stylistOptions.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStylistId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Atribuir a estilista (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Sin atribuir'),
                    ),
                    ...stylistOptions
                        .where((option) => option.stylistId != null)
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.stylistId,
                            child: Text(
                              option.stylistName ?? 'Sin nombre',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStylistId = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Descripcion opcional',
                ),
                minLines: 2,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _pickedImage == null
                      ? 'Elegir foto'
                      : 'Foto elegida: ${_pickedImage!.name}',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_isSaving ? 'Subiendo...' : 'Guardar foto'),
        ),
      ],
    );
  }
}
