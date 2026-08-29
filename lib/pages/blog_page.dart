import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/blog_post.dart';
import '../services/blog_cover_upload_service.dart';
import '../services/blog_service.dart';
import '../services/storage_cleanup.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

/// Panel del blog del negocio (paso 6.6, D-171). Autoservicio: el blog es
/// del tenant, no de una sede, así que solo necesita `tenantId` (para subir
/// portadas) -- ninguna llamada al servidor lleva `branchId`.
class BlogPage extends StatefulWidget {
  const BlogPage({super.key, required this.tenantId});

  final String tenantId;

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  static const _service = BlogService();

  late Future<List<BlogPost>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = _service.getBlogPosts();
  }

  void _refresh() {
    setState(() => _postsFuture = _service.getBlogPosts());
  }

  Future<void> _openEditor({BlogPost? existing}) async {
    final guardado = await showDialog<bool>(
      context: context,
      builder: (_) => _BlogEditorDialog(
        tenantId: widget.tenantId,
        existing: existing,
      ),
    );

    if (guardado == true) _refresh();
  }

  Future<void> _togglePublished(BlogPost post, bool published) async {
    try {
      await _service.updateBlogPost(
        postId: post.id,
        title: post.title,
        content: post.content,
        coverPhotoUrl: post.coverPhotoUrl,
        published: published,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(published ? 'Artículo publicado.' : 'Artículo pasado a borrador.'),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar el estado: $message')),
      );
    }
  }

  Future<void> _delete(BlogPost post) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar este artículo?'),
        content: Text(
          '"${post.title}" se borra definitivamente, incluida su portada. '
          'No se puede deshacer.',
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

    try {
      await const StorageCleanup().borrarPorUrlPublica(
        bucket: 'blog-covers',
        urlPublica: post.coverPhotoUrl,
      );
      await _service.deleteBlogPost(post.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Artículo eliminado.')),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      final message = error is PostgrestException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar el artículo: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BlogPost>>(
      future: _postsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return InfoPanel(
            icon: Icons.error_outline,
            title: 'Error al cargar el blog',
            description: snapshot.error.toString(),
          );
        }

        final posts = snapshot.data ?? [];
        final publicados = posts.where((p) => p.published).length;

        return AppPage(
          title: 'Blog',
          subtitle: 'Artículos de belleza y estética para tu página pública.',
          children: [
            const InfoPanel(
              icon: Icons.article_outlined,
              title: 'Tu propio blog',
              description:
                  'Escribe artículos que aparecen en tu página pública, junto al portafolio y las reseñas. Guarda como borrador y publica cuando estés listo.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                MetricCard(
                  title: 'Artículos',
                  value: '${posts.length}',
                  description: 'Total escritos',
                  icon: Icons.article_outlined,
                ),
                MetricCard(
                  title: 'Publicados',
                  value: '$publicados',
                  description: 'Visibles al público',
                  icon: Icons.public_outlined,
                ),
                MetricCard(
                  title: 'Borradores',
                  value: '${posts.length - publicados}',
                  description: 'Solo tú los ves',
                  icon: Icons.edit_note_outlined,
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Escribir artículo'),
            ),
            const SizedBox(height: 16),
            SectionTitle('Artículos (${posts.length})'),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              const InfoPanel(
                icon: Icons.info_outline,
                title: 'Todavía no has escrito nada',
                description: 'Tu primer artículo puede ser tan simple como un consejo de cuidado que le repites siempre a tus clientas.',
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final post in posts)
                    SizedBox(
                      width: 320,
                      child: _BlogPostCard(
                        post: post,
                        onEdit: () => _openEditor(existing: post),
                        onTogglePublished: (value) => _togglePublished(post, value),
                        onDelete: () => _delete(post),
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

class _BlogPostCard extends StatelessWidget {
  const _BlogPostCard({
    required this.post,
    required this.onEdit,
    required this.onTogglePublished,
    required this.onDelete,
  });

  final BlogPost post;
  final VoidCallback onEdit;
  final ValueChanged<bool> onTogglePublished;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.coverPhotoUrl != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(post.coverPhotoUrl!, fit: BoxFit.cover),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  post.createdDateText,
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const Divider(height: 18),
                Row(
                  children: [
                    Switch(value: post.published, onChanged: onTogglePublished),
                    Expanded(
                      child: Text(post.statusText, style: const TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      color: AppColors.danger,
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlogEditorDialog extends StatefulWidget {
  const _BlogEditorDialog({required this.tenantId, this.existing});

  final String tenantId;
  final BlogPost? existing;

  @override
  State<_BlogEditorDialog> createState() => _BlogEditorDialogState();
}

class _BlogEditorDialogState extends State<_BlogEditorDialog> {
  static const _service = BlogService();
  static const _uploadService = BlogCoverUploadService();

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _coverPhotoUrl;
  bool _published = false;
  bool _subiendoPortada = false;
  bool _guardando = false;
  String? _error;

  bool get _esEdicion => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    _contentController = TextEditingController(text: widget.existing?.content ?? '');
    _coverPhotoUrl = widget.existing?.coverPhotoUrl;
    _published = widget.existing?.published ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _elegirPortada() async {
    final imagen = await _uploadService.pickImage();
    if (imagen == null) return;

    setState(() => _subiendoPortada = true);
    try {
      final url = await _uploadService.uploadCoverPhoto(
        tenantId: widget.tenantId,
        image: imagen,
        previousUrl: _coverPhotoUrl,
      );
      if (!mounted) return;
      setState(() => _coverPhotoUrl = url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir la portada: $error')),
      );
    } finally {
      if (mounted) setState(() => _subiendoPortada = false);
    }
  }

  Future<void> _guardar() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'El título y el contenido no pueden quedar vacíos.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      if (_esEdicion) {
        await _service.updateBlogPost(
          postId: widget.existing!.id,
          title: title,
          content: content,
          coverPhotoUrl: _coverPhotoUrl,
          published: _published,
        );
      } else {
        await _service.createBlogPost(
          title: title,
          content: content,
          coverPhotoUrl: _coverPhotoUrl,
          published: _published,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      final message = error is PostgrestException ? error.message : error.toString();
      if (!mounted) return;
      setState(() {
        _error = message;
        _guardando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_esEdicion ? 'Editar artículo' : 'Escribir artículo'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Contenido',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_coverPhotoUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      child: Image.network(
                        _coverPhotoUrl!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _subiendoPortada ? null : _elegirPortada,
                      icon: _subiendoPortada
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.image_outlined, size: 16),
                      label: Text(_coverPhotoUrl == null ? 'Agregar portada' : 'Cambiar portada'),
                    ),
                  ),
                  if (_coverPhotoUrl != null)
                    IconButton(
                      onPressed: () => setState(() => _coverPhotoUrl = null),
                      icon: const Icon(Icons.close),
                      tooltip: 'Quitar portada',
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _published,
                onChanged: (value) => setState(() => _published = value),
                title: const Text('Publicar (visible en tu página pública)', style: TextStyle(fontSize: 13)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}
