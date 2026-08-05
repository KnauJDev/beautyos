class PublicServiceOption {
  const PublicServiceOption({
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.price,
    required this.durationMinutes,
    required this.stylistId,
    required this.stylistName,
    this.stylistPhotoUrl,
    this.stylistBio,
  });

  final String serviceId;
  final String serviceName;
  final String category;
  final num price;
  final int durationMinutes;
  final String stylistId;
  final String stylistName;
  final String? stylistPhotoUrl;
  final String? stylistBio;

  factory PublicServiceOption.fromMap(Map<String, dynamic> map) {
    return PublicServiceOption(
      serviceId: map['service_id'].toString(),
      serviceName: map['service_name']?.toString() ?? 'Servicio',
      category: map['category']?.toString() ?? 'Sin categoria',
      price: _readNumber(map['price']),
      durationMinutes: _readInt(map['duration_minutes']),
      stylistId: map['stylist_id'].toString(),
      stylistName: map['stylist_name']?.toString() ?? 'Sin estilista',
      stylistPhotoUrl: map['stylist_photo_url']?.toString(),
      stylistBio: map['stylist_bio']?.toString(),
    );
  }

  static num _readNumber(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String get formattedPrice {
    final value = price.toInt().toString();
    final buffer = StringBuffer();

    for (var index = 0; index < value.length; index++) {
      final positionFromEnd = value.length - index;
      buffer.write(value[index]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$$buffer';
  }

  String get label => '$serviceName · $stylistName';
}
