/// Politica unica de compresion de las imagenes que suben al almacen
/// (TL-20, D-199).
///
/// **Por que existe.** Los cinco servicios de subida --logo, portada del
/// negocio, portada de blog, foto de profesional y foto de trabajo-- llamaban
/// a `ImagePicker().pickImage(source: ImageSource.gallery)` **sin ningun
/// limite**: el archivo viajaba tal cual salio del celular. Una foto de un
/// telefono actual son varios megas, y el unico techo era el
/// `file_size_limit` de 10 MB del almacen, que no comprime nada: solo rechaza
/// lo que se pase. Con estos tres limites la misma foto sube a unos cientos
/// de kilobytes -- se paga menos almacenamiento, y sobre todo la pagina
/// publica del salon carga mucho mas rapido, porque quien la abre desde el
/// celular se descarga la imagen entera.
///
/// **Por que en un solo sitio y no repetido en los cinco.** Es la leccion de
/// D-198: tres cifras copiadas cinco veces son cinco sitios que corregir el
/// dia que haya que cambiarlas, y cuatro oportunidades de que una se quede
/// atras. Si manana el criterio cambia, se cambia aqui.
///
/// **Lo que estos limites NO hacen:**
/// - **No rompen la transparencia de un PNG.** Ni la web ni Android
///   recomprimen un PNG con alfa: en web `canvas.toBlob` conserva el tipo
///   original del archivo, y Android guarda como PNG en cuanto el mapa de
///   bits tiene canal alfa. En los dos casos la imagen se reescala, que es
///   justo lo que mas pesa. Un logo con fondo transparente sigue saliendo
///   transparente.
/// - **No tocan los GIF.** El plugin los deja pasar sin reescalar.
library;

import 'package:image_picker/image_picker.dart';

/// Lado maximo, en pixeles, de una imagen subida al almacen.
///
/// 1920 es el ancho de una pantalla Full HD: por encima de eso nadie ve la
/// diferencia en una portada o un logo, y el peso sube al cuadrado.
const double kLadoMaximoDeImagen = 1920;

/// Calidad JPEG/WebP de la imagen subida, de 0 a 100.
///
/// 85 es el punto donde la compresion deja de notarse a simple vista y el
/// archivo ya pesa una fraccion del original.
const int kCalidadDeImagen = 85;

/// Abre el selector de imagenes aplicando la politica de compresion.
///
/// Los cinco servicios de subida llaman aqui. Devuelve `null` si la persona
/// cierra el selector sin elegir nada, igual que `pickImage`.
Future<XFile?> elegirImagenComprimida({
  ImageSource source = ImageSource.gallery,
}) {
  return ImagePicker().pickImage(
    source: source,
    maxWidth: kLadoMaximoDeImagen,
    maxHeight: kLadoMaximoDeImagen,
    imageQuality: kCalidadDeImagen,
  );
}
