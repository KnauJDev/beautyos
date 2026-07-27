class MyStylistReview {
  const MyStylistReview({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String clientName;
  final String serviceName;
  final int rating;
  final String? comment;
  final DateTime? createdAt;

  factory MyStylistReview.fromMap(Map<String, dynamic> map) {
    return MyStylistReview(
      id: map['id']?.toString() ?? '',
      clientName: map['client_name']?.toString() ?? 'Cliente no asociado',
      serviceName: map['service_name']?.toString() ?? 'Servicio no asociado',
      rating: _readInt(map['rating']),
      comment: map['comment']?.toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString())?.toLocal(),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get commentText {
    final value = comment;

    if (value == null || value.trim().isEmpty) {
      return 'Sin comentario.';
    }

    return value;
  }

  String get createdAtText {
    final value = createdAt;

    if (value == null) {
      return 'Sin fecha';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day/$month/$year';
  }
}
