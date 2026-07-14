class TicketPaymentSummary {
  const TicketPaymentSummary({
    required this.totalAmount,
    required this.paidAmount,
    required this.balanceAmount,
    required this.paymentStatus,
  });

  final num totalAmount;
  final num paidAmount;
  final num balanceAmount;
  final String paymentStatus;

  factory TicketPaymentSummary.fromMap(Map<String, dynamic> map) {
    return TicketPaymentSummary(
      totalAmount: _readNumber(map['total_amount']),
      paidAmount: _readNumber(map['paid_amount']),
      balanceAmount: _readNumber(map['balance_amount']),
      paymentStatus: map['payment_status']?.toString() ?? 'sin_pago',
    );
  }
}

class TicketPaymentRecord {
  const TicketPaymentRecord({
    required this.paymentId,
    required this.amount,
    required this.method,
    required this.reference,
    required this.notes,
    required this.status,
    required this.receivedAt,
  });

  final String paymentId;
  final num amount;
  final String method;
  final String? reference;
  final String? notes;
  final String status;
  final DateTime? receivedAt;

  factory TicketPaymentRecord.fromMap(Map<String, dynamic> map) {
    return TicketPaymentRecord(
      paymentId: map['payment_id']?.toString() ?? '',
      amount: _readNumber(map['amount']),
      method: map['method']?.toString() ?? 'otro',
      reference: map['reference']?.toString(),
      notes: map['notes']?.toString(),
      status: map['status']?.toString() ?? '',
      receivedAt: map['received_at'] == null
          ? null
          : DateTime.tryParse(map['received_at'].toString())?.toLocal(),
    );
  }

  String get methodLabel {
    switch (method) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
      case 'transferencia':
        return 'Transferencia';
      default:
        return 'Otro';
    }
  }

  String get receivedAtText {
    final value = receivedAt;

    if (value == null) {
      return 'Sin fecha';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$day/$month/${value.year} $hour:$minute';
  }
}

num _readNumber(dynamic value) {
  if (value is num) {
    return value;
  }

  return num.tryParse(value?.toString() ?? '') ?? 0;
}

String formatMoney(num value) {
  final rawValue = value.toStringAsFixed(0);
  final buffer = StringBuffer();

  for (var index = 0; index < rawValue.length; index++) {
    final positionFromEnd = rawValue.length - index;
    buffer.write(rawValue[index]);

    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }

  return '\$$buffer';
}
