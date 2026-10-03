import 'package:flutter/material.dart';

/// Un calendario que elige con un toque: al tocar el día, queda elegido y se
/// cierra. Sin el paso de "OK".
///
/// **Por qué existe (hallazgo CJ, 03-oct).** El propietario reservó como
/// clienta desde el celular y el calendario de Flutter le pidió confirmar con
/// *OK* un día que ya había tocado, y en inglés. Pidió que en estos
/// formularios *"al seleccionar el día este se seleccione y no haya que dar
/// ok"*. Se usa en los cuatro calendarios de la agenda: la reserva pública,
/// la cita nueva, el salto de fecha del tablero y *Mi agenda* de la
/// estilista. Los demás (gastos, compras, Panel) siguen con el de Flutter,
/// ya en español.
///
/// Devuelve `null` si la persona cancela.
Future<DateTime?> elegirFechaDeUnToque(
  BuildContext context, {
  required DateTime fechaInicial,
  required DateTime primeraFecha,
  required DateTime ultimaFecha,
  String titulo = 'Elige el día',
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (dialogo) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Text(
                titulo,
                style: Theme.of(dialogo).textTheme.titleMedium,
              ),
            ),
            CalendarDatePicker(
              initialDate: fechaInicial,
              firstDate: primeraFecha,
              lastDate: ultimaFecha,
              onDateChanged: (dia) => Navigator.of(dialogo).pop(dia),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 8),
                child: TextButton(
                  onPressed: () => Navigator.of(dialogo).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
