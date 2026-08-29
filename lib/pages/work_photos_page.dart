import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

import '../models/work_photo_summary.dart';
import '../services/work_photos_service.dart';
import '../widgets/app_widgets.dart';
import '../widgets/foto_de_trabajo.dart';
import '../widgets/publication_studio_dialog.dart';

class FotosTrabajosPage extends StatefulWidget {
  const FotosTrabajosPage({super.key, required this.branchId});

  final String branchId;

  @override
  State<FotosTrabajosPage> createState() => _FotosTrabajosPageState();
}

class _FotosTrabajosPageState extends State<FotosTrabajosPage> {
  late final WorkPhotosService _workPhotosService;

  late Future<List<WorkPhotoSummary>> _workPhotosFuture;
  String _selectedFilter = 'all';
  String _selectedStylist = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _workPhotosService = WorkPhotosService(branchId: widget.branchId);
    _workPhotosFuture = _workPhotosService.getWorkPhotosSummary();
  }

  List<WorkPhotoSummary> _filterPhotos(List<WorkPhotoSummary> photos) {
    return photos.where((photo) {
      // 1. Filtro por tipo o estado
      switch (_selectedFilter) {
        case 'visible':
          if (!photo.visibleToCustomer) return false;
          break;
        case 'portfolio':
          if (!photo.approvedForPortfolio) return false;
          break;
        case 'pending_ai':
          if (photo.aiStatus != 'pending') return false;
          break;
        case 'before':
        case 'after':
        case 'final':
          if (photo.photoType != _selectedFilter) return false;
          break;
        case 'all':
        default:
          break;
      }

      // 2. Filtro por estilista
      if (_selectedStylist != 'all') {
        if (photo.stylistName != _selectedStylist) return false;
      }

      // 3. Filtro por texto de búsqueda
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final clientMatch = photo.clientName.toLowerCase().contains(query);
        final stylistMatch = photo.stylistName.toLowerCase().contains(query);
        final ticketMatch = (photo.ticketCode ?? '').toLowerCase().contains(query);
        final captionMatch = (photo.caption ?? '').toLowerCase().contains(query);

        if (!clientMatch && !stylistMatch && !ticketMatch && !captionMatch) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _refreshPhotos() {
    setState(() {
      _workPhotosFuture = _workPhotosService.getWorkPhotosSummary();
    });
  }

  Future<void> _setCustomerVisibility(
    WorkPhotoSummary photo,
    bool visible,
  ) async {
    try {
      await _workPhotosService.setCustomerVisibility(
        photoId: photo.id,
        visible: visible,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            visible ? 'Foto visible al cliente.' : 'Foto ocultada al cliente.',
          ),
        ),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar la visibilidad: $message')),
      );
    }
  }

  Future<void> _setPortfolioApproval(
    WorkPhotoSummary photo,
    bool approved,
  ) async {
    try {
      if (photo.storagePath == null) {
        throw StateError(
          'Esta foto no tiene ruta de archivo y no se puede publicar. '
          'Vuelve a subirla.',
        );
      }

      await _workPhotosService.setPortfolioApproval(
        photoId: photo.id,
        approved: approved,
        storagePath: photo.storagePath!,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? 'Foto aprobada para portafolio.'
                : 'Foto retirada del portafolio.',
          ),
        ),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo aprobar la foto: $message')),
      );
    }
  }

  /// Borrar una foto no se puede deshacer (H-09).
  Future<void> _deletePhoto(WorkPhotoSummary photo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar esta foto?'),
        content: const Text(
          'La imagen se borra definitivamente y no se puede recuperar: las '
          'fotos no se guardan en los respaldos.\n\n'
          'Si la foto está publicada, dejará de verse en internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final ruta = photo.storagePath;

    if (ruta == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta foto ya no tiene archivo asociado.'),
        ),
      );
      return;
    }

    try {
      await _workPhotosService.deleteWorkPhoto(
        photoId: photo.id,
        bucket: photo.storageBucket,
        storagePath: ruta,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto eliminada.')),
      );
      _refreshPhotos();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException
          ? error.message
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la foto: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkPhotoSummary>>(
      future: _workPhotosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar fotos',
            description: snapshot.error.toString(),
          );
        }

        final allPhotos = snapshot.data ?? [];
        final filteredPhotos = _filterPhotos(allPhotos);

        // Estilistas únicos para el filtro
        final stylists = allPhotos
            .map((p) => p.stylistName)
            .where((name) => name.trim().isNotEmpty && name != 'Estilista no asociado')
            .toSet()
            .toList()
          ..sort();

        return _WorkPhotosContent(
          allPhotos: allPhotos,
          photos: filteredPhotos,
          stylists: stylists,
          selectedFilter: _selectedFilter,
          selectedStylist: _selectedStylist,
          searchQuery: _searchQuery,
          onSearchChanged: (query) => setState(() => _searchQuery = query),
          onFilterChanged: (filter) => setState(() => _selectedFilter = filter),
          onStylistChanged: (stylist) => setState(() => _selectedStylist = stylist),
          onClearFilters: () {
            setState(() {
              _selectedFilter = 'all';
              _selectedStylist = 'all';
              _searchQuery = '';
            });
          },
          onRefresh: _refreshPhotos,
          onSetCustomerVisibility: _setCustomerVisibility,
          onSetPortfolioApproval: _setPortfolioApproval,
          onDelete: _deletePhoto,
          onOpenPublicationStudio: (photo) => showPublicationStudioDialog(
            context,
            branchId: widget.branchId,
            photo: photo,
          ),
        );
      },
    );
  }
}

class _WorkPhotosContent extends StatelessWidget {
  final List<WorkPhotoSummary> allPhotos;
  final List<WorkPhotoSummary> photos;
  final List<String> stylists;
  final String selectedFilter;
  final String selectedStylist;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<String> onStylistChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onRefresh;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
      onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
      onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;
  final Future<void> Function(WorkPhotoSummary photo) onOpenPublicationStudio;

  const _WorkPhotosContent({
    required this.allPhotos,
    required this.photos,
    required this.stylists,
    required this.selectedFilter,
    required this.selectedStylist,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onStylistChanged,
    required this.onClearFilters,
    required this.onRefresh,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
    required this.onOpenPublicationStudio,
  });

  @override
  Widget build(BuildContext context) {
    final totalPhotos = allPhotos.length;
    final visiblePhotos = allPhotos
        .where((photo) => photo.visibleToCustomer)
        .length;
    final portfolioPhotos = allPhotos
        .where((photo) => photo.approvedForPortfolio)
        .length;
    final pendingAiPhotos = allPhotos
        .where((photo) => photo.aiStatus == 'pending')
        .length;

    return AppPage(
      title: 'Fotos de trabajos',
      subtitle:
          'Portafolio visual, evidencia de servicios con ticket y control de publicación.',
      children: [
        const InfoPanel(
          icon: Icons.photo_library_outlined,
          title: 'Galería conectada a Supabase',
          description:
              'Visualiza fotos antes, después y finales vinculadas a cada cita (#ticket). Filtra por estilista o cliente y aprueba las mejores para el portafolio público.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            MetricCard(
              title: 'Fotos',
              value: '$totalPhotos',
              description: 'Registros cargados',
              icon: Icons.image_outlined,
            ),
            MetricCard(
              title: 'Visibles',
              value: '$visiblePhotos',
              description: 'Fotos visibles al cliente',
              icon: Icons.visibility_outlined,
            ),
            MetricCard(
              title: 'Portafolio',
              value: '$portfolioPhotos',
              description: 'Fotos aprobadas',
              icon: Icons.collections_outlined,
            ),
            MetricCard(
              title: 'IA pendiente',
              value: '$pendingAiPhotos',
              description: 'Fotos por procesar',
              icon: Icons.auto_awesome_outlined,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Buscador y Filtros
        Card(
          elevation: 1,
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente, estilista, #cita (ej. #0000701) o notas...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => onSearchChanged(''),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 12),

                // Filtros de Tipo
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Todas ($totalPhotos)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('portfolio', '⭐ Portafolio ($portfolioPhotos)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('visible', '👁️ Visibles ($visiblePhotos)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('before', 'Antes'),
                      const SizedBox(width: 8),
                      _buildFilterChip('after', 'Después'),
                      const SizedBox(width: 8),
                      _buildFilterChip('final', 'Final'),
                      if (pendingAiPhotos > 0) ...[
                        const SizedBox(width: 8),
                        _buildFilterChip('pending_ai', '🤖 IA pendiente ($pendingAiPhotos)'),
                      ],
                    ],
                  ),
                ),

                // Filtro de Estilista (si hay estilistas)
                if (stylists.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text(
                          'Estilista: ',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: selectedStylist == 'all',
                          selectedColor: AppColors.brandTint,
                          onSelected: (selected) {
                            if (selected) onStylistChanged('all');
                          },
                        ),
                        for (final stylist in stylists) ...[
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(stylist),
                            selected: selectedStylist == stylist,
                            selectedColor: AppColors.brandTint,
                            onSelected: (selected) {
                              if (selected) onStylistChanged(stylist);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            SectionTitle('Galería de trabajos (${photos.length})'),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WorkPhotosGrid(
          photos: photos,
          onClearFilters: onClearFilters,
          onSetCustomerVisibility: onSetCustomerVisibility,
          onSetPortfolioApproval: onSetPortfolioApproval,
          onDelete: onDelete,
          onOpenPublicationStudio: onOpenPublicationStudio,
        ),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = selectedFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.brandTint,
      onSelected: (selected) {
        if (selected) onFilterChanged(key);
      },
    );
  }
}

class _WorkPhotosGrid extends StatelessWidget {
  final List<WorkPhotoSummary> photos;
  final VoidCallback onClearFilters;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
      onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
      onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;
  final Future<void> Function(WorkPhotoSummary photo) onOpenPublicationStudio;

  const _WorkPhotosGrid({
    required this.photos,
    required this.onClearFilters,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
    required this.onOpenPublicationStudio,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined, size: 48, color: AppColors.textMuted),
                const SizedBox(height: 12),
                const Text(
                  'No hay fotos que coincidan con la búsqueda o filtro.',
                  style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onClearFilters,
                  child: const Text('Limpiar filtros'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final photo in photos)
          SizedBox(
            width: 290,
            child: _WorkPhotoCard(
              photo: photo,
              onSetCustomerVisibility: onSetCustomerVisibility,
              onSetPortfolioApproval: onSetPortfolioApproval,
              onDelete: onDelete,
              onOpenPublicationStudio: onOpenPublicationStudio,
            ),
          ),
      ],
    );
  }
}

class _WorkPhotoCard extends StatelessWidget {
  final WorkPhotoSummary photo;
  final Future<void> Function(WorkPhotoSummary photo, bool visible)
      onSetCustomerVisibility;
  final Future<void> Function(WorkPhotoSummary photo, bool approved)
      onSetPortfolioApproval;
  final Future<void> Function(WorkPhotoSummary photo) onDelete;
  final Future<void> Function(WorkPhotoSummary photo) onOpenPublicationStudio;

  const _WorkPhotoCard({
    required this.photo,
    required this.onSetCustomerVisibility,
    required this.onSetPortfolioApproval,
    required this.onDelete,
    required this.onOpenPublicationStudio,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: FotoDeTrabajo(url: photo.displayUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PhotoTypeBadge(text: photo.photoTypeText),
                    const SizedBox(width: 6),
                    _ConsentBadge(hasConsent: photo.clientConsent),
                    const Spacer(),
                    if (photo.ticketCode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brandTint,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          photo.ticketCode!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandDeep,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  photo.captionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        photo.clientName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.content_cut_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        photo.stylistName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${photo.createdDateText} · ${photo.aiStatusText}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Switch(
                      value: photo.visibleToCustomer,
                      onChanged: (value) =>
                          onSetCustomerVisibility(photo, value),
                    ),
                    const Expanded(
                      child: Text(
                        'Visible al cliente',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Switch(
                      value: photo.approvedForPortfolio,
                      onChanged: (value) =>
                          onSetPortfolioApproval(photo, value),
                    ),
                    const Expanded(
                      child: Text(
                        'Aprobada portafolio',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onDelete(photo),
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.danger,
                      tooltip: 'Eliminar foto',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Tooltip(
                    message: photo.estaPublicada
                        ? 'Compone una imagen lista para Instagram con esta foto'
                        : 'Primero hay que aprobarla para portafolio',
                    child: OutlinedButton.icon(
                      onPressed: photo.estaPublicada
                          ? () => onOpenPublicationStudio(photo)
                          : null,
                      icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                      label: const Text(
                        'Estudio de publicación',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador visual de consentimiento (Ley 1581, D-167): si la clienta
/// autorizó publicar la foto o si es solo archivo interno privado.
class _ConsentBadge extends StatelessWidget {
  final bool hasConsent;

  const _ConsentBadge({required this.hasConsent});

  @override
  Widget build(BuildContext context) {
    final color = hasConsent ? AppColors.success : AppColors.textMuted;
    return Tooltip(
      message: hasConsent
          ? 'La clienta autorizó publicar esta foto (Ley 1581)'
          : 'Sin autorización de la clienta: solo archivo interno privado',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasConsent ? Icons.verified_user_outlined : Icons.lock_outline,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              hasConsent ? 'Autorizada' : 'Solo archivo interno',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTypeBadge extends StatelessWidget {
  final String text;

  const _PhotoTypeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
