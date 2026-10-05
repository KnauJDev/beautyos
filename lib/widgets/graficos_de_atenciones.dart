import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/dashboard_de_atenciones.dart';
import '../theme/app_theme.dart';

/// Los gráficos del Dashboard de atenciones (D-317).
///
/// Dibujados a la medida, y no con `fl_chart`, porque el prototipo que aprobó
/// el propietario combina en un mismo gráfico las barras del periodo y la
/// línea punteada del anterior, y pinta un mapa de calor: dos cosas que esa
/// librería no trae juntas. Los colores salen del tema del negocio
/// (`AppColors.brand…`), así que con Inspirant son dorados y con Morado,
/// morados.

/// La línea chiquita de tendencia de cada indicador.
class LineaDeTendencia extends StatelessWidget {
  const LineaDeTendencia({super.key, required this.valores, this.alto = 30});

  final List<num> valores;
  final double alto;

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) return SizedBox(height: alto);
    return SizedBox(
      height: alto,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorDeTendencia(valores, AppColors.brand),
      ),
    );
  }
}

class _PintorDeTendencia extends CustomPainter {
  _PintorDeTendencia(this.valores, this.color);

  final List<num> valores;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // `fold` y no `reduce(math.max)`: la lista llega como `List<int>` aunque
    // se declare de `num`, y `reduce` revienta al combinar (lo cazó la prueba
    // del tablero dibujado, 04-oct).
    final maximo = valores.fold<num>(1, (m, v) => math.max(m, v)).toDouble();
    final n = valores.length;
    final puntos = <Offset>[
      for (var k = 0; k < n; k++)
        Offset(
          k * size.width / (n - 1),
          size.height - 3 - (valores[k] / maximo) * (size.height - 6),
        ),
    ];
    final linea = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      linea.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linea)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.14));
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(puntos.last, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PintorDeTendencia old) =>
      old.valores != valores || old.color != color;
}

/// Las citas atendidas por día (o semana, o mes) contra la línea punteada del
/// periodo anterior. Tocar una barra dice su número.
class BarrasConComparacion extends StatefulWidget {
  const BarrasConComparacion({
    super.key,
    required this.actual,
    required this.anterior,
    required this.granularidad,
    this.hoy,
  });

  final List<PuntoDeSerie> actual;
  final List<PuntoDeSerie> anterior;
  final String granularidad;

  /// Para pintar la barra de hoy distinta: el día va por la mitad.
  final DateTime? hoy;

  @override
  State<BarrasConComparacion> createState() => _BarrasConComparacionState();
}

class _BarrasConComparacionState extends State<BarrasConComparacion> {
  int? _tocada;

  String _nombre(DateTime d) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago',
      'sep', 'oct', 'nov', 'dic'];
    switch (widget.granularidad) {
      case 'week':
        return 'semana del ${d.day} ${meses[d.month - 1]}';
      case 'month':
        return '${meses[d.month - 1]} ${d.year}';
      default:
        return '${diasDeLaSemana[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = _tocada;
    final detalle = i == null || i >= widget.actual.length
        ? 'Toca una barra para ver el número.'
        : '${_nombre(widget.actual[i].desde)}: ${miles(widget.actual[i].atendidas)} '
              '${widget.actual[i].atendidas == 1 ? 'atendida' : 'atendidas'}'
              '${i < widget.anterior.length ? ' · antes ${miles(widget.anterior[i].atendidas)}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          detalle,
          style: TextStyle(
            fontSize: 12.5,
            color: i == null ? AppColors.textSecondary : AppColors.textPrimary,
            fontWeight: i == null ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, c) {
            final ancho = c.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (e) {
                final n = widget.actual.length;
                if (n == 0) return;
                final usable = ancho - _PintorDeBarras.izquierda - _PintorDeBarras.derecha;
                final k = ((e.localPosition.dx - _PintorDeBarras.izquierda) / (usable / n))
                    .floor()
                    .clamp(0, n - 1);
                setState(() => _tocada = _tocada == k ? null : k);
              },
              child: SizedBox(
                height: 200,
                width: ancho,
                child: CustomPaint(
                  painter: _PintorDeBarras(
                    actual: widget.actual,
                    anterior: widget.anterior,
                    granularidad: widget.granularidad,
                    hoy: widget.hoy,
                    tocada: _tocada,
                    barra: AppColors.brand,
                    barraFuerte: AppColors.brandDark,
                    barraHoy: AppColors.brandTint,
                    linea: AppColors.textMuted,
                    rejilla: AppColors.border,
                    texto: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _PintorDeBarras extends CustomPainter {
  _PintorDeBarras({
    required this.actual,
    required this.anterior,
    required this.granularidad,
    required this.hoy,
    required this.tocada,
    required this.barra,
    required this.barraFuerte,
    required this.barraHoy,
    required this.linea,
    required this.rejilla,
    required this.texto,
  });

  static const izquierda = 30.0;
  static const derecha = 6.0;
  static const arriba = 8.0;
  static const abajo = 22.0;

  final List<PuntoDeSerie> actual;
  final List<PuntoDeSerie> anterior;
  final String granularidad;
  final DateTime? hoy;
  final int? tocada;
  final Color barra, barraFuerte, barraHoy, linea, rejilla, texto;

  void _escribir(Canvas canvas, String s, Offset donde, {TextAlign al = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: texto, fontSize: 10.5)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = al == TextAlign.right
        ? donde.dx - tp.width
        : al == TextAlign.center
        ? donde.dx - tp.width / 2
        : donde.dx;
    tp.paint(canvas, Offset(dx, donde.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = actual.length;
    if (n == 0) return;
    final valores = [
      ...actual.map((p) => p.atendidas),
      ...anterior.take(n).map((p) => p.atendidas),
    ];
    final maximo = math.max(4, valores.isEmpty ? 0 : valores.reduce(math.max));
    final paso = maximo <= 10
        ? 2
        : maximo <= 30
        ? 5
        : maximo <= 80
        ? 10
        : maximo <= 200
        ? 25
        : 50;
    final tope = (maximo / paso).ceil() * paso;
    final alto = size.height - arriba - abajo;
    double y(num v) => arriba + alto * (1 - v / tope);

    final pRejilla = Paint()
      ..color = rejilla
      ..strokeWidth = 1;
    for (var v = 0; v <= tope; v += paso) {
      canvas.drawLine(Offset(izquierda, y(v)), Offset(size.width - derecha, y(v)), pRejilla);
      _escribir(canvas, '$v', Offset(izquierda - 6, y(v)), al: TextAlign.right);
    }

    final ancho = (size.width - izquierda - derecha) / n;
    final cadaEtiqueta = (n / 8).ceil();
    for (var k = 0; k < n; k++) {
      final p = actual[k];
      final x = izquierda + k * ancho + ancho * 0.16;
      final w = ancho * 0.68;
      final esHoy = granularidad == 'day' &&
          hoy != null &&
          p.desde.year == hoy!.year &&
          p.desde.month == hoy!.month &&
          p.desde.day == hoy!.day;
      final color = esHoy
          ? barraHoy
          : (granularidad == 'day' && p.desde.weekday == DateTime.saturday)
          ? barraFuerte
          : barra;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTRB(x, y(p.atendidas), x + w, y(0)),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = (tocada != null && tocada != k) ? color.withValues(alpha: 0.45) : color,
      );
      if (esHoy) {
        canvas.drawRRect(
          rect,
          Paint()
            ..color = barra
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
      if (k % cadaEtiqueta == 0) {
        final etiqueta = granularidad == 'day'
            ? '${p.desde.day}'
            : granularidad == 'week'
            ? '${p.desde.day}/${p.desde.month}'
            : '${p.desde.month}/${p.desde.year % 100}';
        _escribir(canvas, etiqueta, Offset(izquierda + k * ancho + ancho / 2, size.height - abajo / 2));
      }
    }

    // La línea punteada del periodo anterior, alineada barra con barra.
    final m = math.min(n, anterior.length);
    if (m >= 2) {
      final pLinea = Paint()
        ..color = linea
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      for (var k = 0; k < m - 1; k++) {
        final a = Offset(izquierda + k * ancho + ancho / 2, y(anterior[k].atendidas));
        final b = Offset(izquierda + (k + 1) * ancho + ancho / 2, y(anterior[k + 1].atendidas));
        _punteada(canvas, a, b, pLinea);
      }
    }
  }

  void _punteada(Canvas canvas, Offset a, Offset b, Paint p) {
    const trazo = 5.0, hueco = 4.0;
    final d = (b - a).distance;
    if (d == 0) return;
    final dir = (b - a) / d;
    var recorrido = 0.0;
    while (recorrido < d) {
      final fin = math.min(recorrido + trazo, d);
      canvas.drawLine(a + dir * recorrido, a + dir * fin, p);
      recorrido += trazo + hueco;
    }
  }

  @override
  bool shouldRepaint(_PintorDeBarras old) => true;
}

/// Día de la semana contra hora: dónde se concentran las citas. Tocar una
/// celda dice cuántas hubo.
class MapaDeCalor extends StatelessWidget {
  const MapaDeCalor({
    super.key,
    required this.celdas,
    this.desde = 8,
    this.hasta = 19,
  });

  final List<CeldaDeCalor> celdas;

  /// Las horas que se muestran (de [desde] a [hasta], ambas incluidas). Si
  /// hay citas fuera de ese rango, se amplía solo.
  final int desde;
  final int hasta;

  @override
  Widget build(BuildContext context) {
    final conCitas = celdas.where((c) => c.atendidas > 0);
    final primera = conCitas.isEmpty ? desde : math.min(desde, conCitas.map((c) => c.hora).reduce(math.min));
    final ultima = conCitas.isEmpty ? hasta : math.max(hasta, conCitas.map((c) => c.hora).reduce(math.max));
    final horas = [for (var h = primera; h <= ultima; h++) h];
    final valor = <(int, int), int>{
      for (final c in celdas) (c.diaSemana, c.hora): c.atendidas,
    };
    final maximo = math.max(1, valor.values.fold<int>(0, math.max));
    CeldaDeCalor? pico;
    for (final c in celdas) {
      if (c.atendidas > 0 && (pico == null || c.atendidas > pico.atendidas)) pico = c;
    }

    Widget fila(List<Widget> hijos) => Row(children: hijos);

    return Column(
      children: [
        fila([
          const SizedBox(width: 34),
          for (final h in horas)
            Expanded(
              child: Text(
                '${h <= 12 ? h : h - 12}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        for (var d = 1; d <= 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: fila([
              SizedBox(
                width: 34,
                child: Text(
                  diasCortos[d - 1],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final h in horas)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      message:
                          '${diasDeLaSemana[d - 1]} de ${horaHablada(h)} a ${horaHablada(h + 1)}: '
                          '${valor[(d, h)] ?? 0} ${(valor[(d, h)] ?? 0) == 1 ? 'cita' : 'citas'}',
                      child: AspectRatio(
                        aspectRatio: 1.25,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(
                              alpha: 0.05 + 0.95 * ((valor[(d, h)] ?? 0) / maximo),
                            ),
                            borderRadius: BorderRadius.circular(4),
                            border: (pico != null && pico.diaSemana == d && pico.hora == h)
                                ? Border.all(color: AppColors.textPrimary, width: 2)
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
      ],
    );
  }
}

/// La dona de en línea contra el salón, con el porcentaje en el centro.
class DonaEnLinea extends StatelessWidget {
  const DonaEnLinea({super.key, required this.enLinea, required this.total});

  final int enLinea;
  final int total;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: CustomPaint(
        painter: _PintorDeDona(
          fraccion: total == 0 ? 0 : enLinea / total,
          enLinea: AppColors.brand,
          salon: AppColors.brandDeep,
          vacio: AppColors.brandTintSoft,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${porcentaje(enLinea, total)} %',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              Text(
                'en línea',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorDeDona extends CustomPainter {
  _PintorDeDona({
    required this.fraccion,
    required this.enLinea,
    required this.salon,
    required this.vacio,
  });

  final double fraccion;
  final Color enLinea, salon, vacio;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 18.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - grosor / 2,
    );
    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    if (fraccion <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, p(vacio));
      return;
    }
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, p(salon));
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * fraccion, false, p(enLinea));
  }

  @override
  bool shouldRepaint(_PintorDeDona old) =>
      old.fraccion != fraccion || old.enLinea != enLinea || old.salon != salon;
}

/// Clientas nuevas y las que vuelven, semana por semana.
class SemanasApiladas extends StatelessWidget {
  const SemanasApiladas({super.key, required this.semanas});

  final List<SemanaDeClientas> semanas;

  @override
  Widget build(BuildContext context) {
    if (semanas.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: CustomPaint(
        painter: _PintorDeSemanas(
          semanas: semanas,
          vuelven: AppColors.brand,
          nuevas: AppColors.brandDeep,
          texto: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _PintorDeSemanas extends CustomPainter {
  _PintorDeSemanas({
    required this.semanas,
    required this.vuelven,
    required this.nuevas,
    required this.texto,
  });

  final List<SemanaDeClientas> semanas;
  final Color vuelven, nuevas, texto;

  @override
  void paint(Canvas canvas, Size size) {
    const abajo = 18.0;
    final maximo = math.max(2, semanas.map((s) => s.nuevas + s.vuelven).reduce(math.max));
    final alto = size.height - abajo;
    final ancho = size.width / semanas.length;
    double y(num v) => alto * (1 - v / maximo);
    for (var k = 0; k < semanas.length; k++) {
      final s = semanas[k];
      // Con una o dos semanas la barra ocupaba todo el ancho y parecía un
      // bloque (visto en el espejo, 04-oct): máximo 56 de ancho.
      final w = math.min(ancho * 0.64, 56.0);
      final x = k * ancho + (ancho - w) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(x, y(s.vuelven), x + w, alto), const Radius.circular(2)),
        Paint()..color = vuelven,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, y(s.vuelven + s.nuevas), x + w, y(s.vuelven)),
          const Radius.circular(2),
        ),
        Paint()..color = nuevas,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${s.semana.day}/${s.semana.month}',
          style: TextStyle(color: texto, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      if (semanas.length <= 8 || k % (semanas.length / 8).ceil() == 0) {
        tp.paint(canvas, Offset(k * ancho + ancho / 2 - tp.width / 2, alto + 4));
      }
    }
  }

  @override
  bool shouldRepaint(_PintorDeSemanas old) => true;
}

/// Un renglón de ranking: nombre, número, porcentaje y su barra. Se toca para
/// filtrar todo el tablero por él, como en Power BI.
class RenglonDeRanking extends StatelessWidget {
  const RenglonDeRanking({
    super.key,
    required this.titulo,
    this.detalle,
    required this.valor,
    this.extra,
    required this.fraccion,
    required this.seleccionado,
    required this.atenuado,
    required this.onTap,
    this.inicial,
    this.datos,
  });

  final String titulo;
  final String? detalle;
  final String valor;
  final String? extra;

  /// Largo de la barra, de 0 a 1.
  final double fraccion;
  final bool seleccionado;
  final bool atenuado;
  final VoidCallback onTap;

  /// La letra del círculo, para el equipo.
  final String? inicial;

  /// Una línea de datos debajo de la barra (horas, nuevas, estrellas).
  final String? datos;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: atenuado ? 0.4 : 1,
      child: Material(
        color: seleccionado ? AppColors.brandTint : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (inicial != null) ...[
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.brandTint,
                    foregroundColor: AppColors.brandDark,
                    child: Text(inicial!, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: titulo,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                children: [
                                  if (detalle != null)
                                    TextSpan(
                                      text: '  $detalle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          if (extra != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              extra!,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: fraccion.clamp(0, 1).toDouble(),
                          minHeight: 8,
                          backgroundColor: AppColors.brandTintSoft,
                          valueColor: AlwaysStoppedAnimation(AppColors.brand),
                        ),
                      ),
                      if (datos != null) ...[
                        const SizedBox(height: 5),
                        Text(datos!, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
