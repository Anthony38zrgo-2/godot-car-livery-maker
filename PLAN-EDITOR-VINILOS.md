# Plan: editor de libreas por capas para Polyphony001

Estado: propuesta de implementacion. No implementa la feature.

## Objetivo y alcance

Crear una experiencia de colocacion de vinilos inspirada en el flujo solicitado de NFS World: formas y numeros editables sobre el coche, con vista previa inmediata. Reproducir las zonas azul oscuro, cian, blanco y amarillo de la referencia Benetton B195 sin patrocinadores. Incluir color base de carroceria, color de rines y acabado por capa, incluida fibra de carbono.

## Estado actual observado

- livery_studio.gd concentra carga GLB, UI, orbitado, pincel y guardado.
- El documento actual guarda modelo, atlas EXR y shader; no guarda objetos vinilo editables.
- OverlayAtlasManager recorre todas las mallas y aplica el overlay sin una clasificacion de zonas.
- default_overlay.gdshader mezcla color y alfa; no ofrece canales separados de rugosidad, metalicidad o normal para acabados.
- Los cuatro GLB de coche ya tienen UV2 y el piloto separado. Los .blend originales siguen siendo fuentes, con otras geometrías ocultas: no exportarlos indiscriminadamente.

## Decisiones de producto

1. Centro: coche con seleccion directa y manipulador del vinilo. Izquierda: biblioteca de formas. Derecha: propiedades. Panel de capas ordenable, ocultable y bloqueable.
2. Vistas lateral izquierda/derecha, superior, frontal, trasera y libre. Camara ortografica para alinear diseños; perspectiva para revisar el acabado.
3. Biblioteca inicial: franja recta, franja doble/triple, franja afinada, diagonal, curva ajustable, rectangulo, rectangulo redondeado, trapecio, triangulo, circulo y numeros 0-99 con fuente redistribuible.
4. Cada capa tiene nombre, forma o numero, color HEX/RGBA, opacidad, posicion, rotacion, ancho/alto independientes, bloqueo de proporcion, espejo y borde con ancho/color propios. Presets horizontal y vertical equivalen a 0/90 grados respecto al plano local de colocacion.
5. Duplicar, reflejar al otro lado, ordenar, ocultar, bloquear y eliminar; deshacer/rehacer todas las operaciones. El reflejo de numeros permite conservar su lectura, sin invertir los digitos.
6. Acabados iniciales: mate, satinado, brillante y metalizado. Carbono como material de una capa o zona, con escala y orientacion de trama. Un borde puede tener acabado propio.
7. Color base por carroceria completa y color de rines como ajustes independientes. Se sustituyen los colores/graficos del albedo original solo en las zonas habilitadas, conservando detalles geometricos y materiales protegidos.

## Proteccion de superficies: primer requisito tecnico

Crear un perfil por variante, basado en caras/superficies y no solo en nombre de objeto o material. Una misma malla body contiene carroceria y piezas mecanicas; clasificarla entera como pintable seria incorrecto.

Categorias: carroceria pintable, rin recoloreable y protegido. Proteger fondo plano, difusor, suspension y neumaticos. Los pilotos quedan fuera del editor de coches. Separar discos, bujes e interiores del rin cuando existan; no recolorear por proximidad espacial.

Preparar un manifiesto por GLB con hash, IDs estables, superficie/triangulos de origen y categoria. Generar una mascara de categorias en UV2 y un pase de seleccion que use la misma clasificacion. La vista de diagnostico colorea cada categoria para revision manual de las cuatro variantes. Si cambia el hash del modelo, no aplicar silenciosamente un perfil antiguo.

## Proyeccion y adaptacion al coche

Los vinilos son datos vectoriales/procedurales, no pinceladas irreversibles. Cada vinilo conserva un marco 3D local de proyeccion, orientacion, dimensiones, profundidad y conjunto de superficies destino. El raycast/pase de picking fija el anclaje sobre una superficie permitida.

Rasterizar la forma hacia UV2 mediante proyeccion sobre las caras del coche. Filtrar por categoria, profundidad, normales y visibilidad para impedir atravesar el coche o pintar suspension situada detras. Al rotar la camara, la colocacion del vinilo permanece fija en el modelo.

La proyeccion se adapta a la superficie, pero una proyeccion plana puede estirar el diseño en curvas fuertes. Proveer repeticion de la misma capa en varios parches de proyeccion, o dividirla conservando sus parametros comunes. Empezar por proyeccion planar y reflejo; añadir envoltura guiada despues de validar el B195. No prometer envoltura universal sin distorsion.

## Materiales y composicion

Crear un compositor de capas que produzca albedo, cobertura, rugosidad, metalicidad y normal de detalle. Componer en el mismo orden y con las mismas mascaras todos los canales. El acabado visible de una zona corresponde a la capa superior que la cubre, mezclado por su cobertura.

Usar un material de carroceria integrado que combine base y mapas compuestos; no apilar geometria coplanar para cada vinilo. Mantener el pase de coordenadas requerido por CameraBrush separado del sombreado final para no alterar su codificacion. Los materiales protegidos conservan su representacion original.

Carbono: trama procedural o textura tileable redistribuible, normal de detalle, rugosidad y orientacion configurables. Carbono pintado puede tener color/tinte y capa de barniz; no tratarlo simplemente como gris oscuro metalizado.

Implementar el color del rin en su material especifico, separado de los atlas de carroceria. Añadir iluminacion de estudio con reflexiones y presets de luz para distinguir brillo y metalizado; el fondo y la luz no se guardan como parte de la pintura.

## Estructura propuesta

- livery_studio.gd: coordinacion de la aplicacion, delegando UI y herramientas.
- studio/model_profile.gd y data/polyphony001/: categorias, IDs y perfiles verificados.
- studio/livery_document.gd: documento versionado y pila de capas.
- studio/vinyl_layer.gd: parametros de forma, transformacion, destinos y acabado.
- studio/vinyl_projector.gd: picking, marco de proyeccion y mascaras.
- studio/livery_compositor.gd y shaders/: composicion y materiales PBR.
- studio/livery_history.gd: comandos de deshacer/rehacer.
- studio/ui/: biblioteca, lista de capas, propiedades y vistas.

Mantener el addon como soporte del pincel y del pase UV; adaptar su aplicacion de materiales para respetar categorias, sin depender de recorrer y pintar todas las mallas.

## Guardado y compatibilidad

Formato v2 bajo liveries/<nombre>/: proyecto.json, recursos locales y mapas derivados. Guardar capas y sus parametros, colores base/rin, perfil/hash del modelo, version de composicion y assets necesarios con rutas relativas. Los atlas son cache regenerable, no la unica copia del trabajo.

Abrir una librea v1 conservando su EXR como capa raster bloqueada. No inventar vinilos editables a partir de un atlas ya aplanado. Guardar por archivo temporal y reemplazo, con copia anterior recuperable.

Exportar GLB con albedo y mapas PBR horneados para revision en otros visores. El documento v2 conserva la edicion de capas aunque el GLB exportado este aplanado. Evitar depender de ShaderMaterial exclusivo de Godot en la exportacion.

## Implementacion por entregas

1. Perfiles y mascaras: clasificar las cuatro variantes y validar restricciones. Resultado: carroceria/rines seleccionables y mecanica bloqueada.
2. Material base: eliminar graficos anteriores solo en carroceria, color base, rines y acabados PBR. Resultado: coche limpio con materiales revisables.
3. Capas y proyeccion: formas, numeros, borde, transformaciones, reflejo y orden. Resultado: esquema B195 sin patrocinadores reproducible.
4. Carbono, acabados por capa e historial; guardado v2, migracion v1 y recuperacion.
5. Exportacion GLB y pruebas de uso completas; ajustar rendimiento y calidad de bordes.

Validar la entrega 1 antes de expandir la biblioteca. Preparar el esquema B195 como documento de ejemplo usando solamente formas y numero 1.

## Criterios de aceptacion

- Arrastrar una franja desde el ponton hacia una rueda nunca pinta neumatico, suspension ni fondo plano. Sus materiales y mapas siguen iguales tras guardar/exportar.
- Un vinilo mantiene posicion y tamaño al orbitar; sus limites no aparecen en el lado opuesto salvo reflejo explicito.
- Horizontal, vertical y rotacion arbitraria funcionan con ancho/alto independiente; borde y color HEX se conservan exactamente como parametros.
- Reordenar, ocultar, editar o deshacer una capa recompone color y acabado de forma coherente.
- Guardar, cerrar y reabrir conserva capas, proyecciones, materiales y numeros. Abrir v1 conserva su apariencia como capa raster.
- Los cuatro modelos permiten carroceria base y rines de colores diferentes, sin recolorear neumaticos, discos o suspension.
- Mate, brillante y metalizado se distinguen bajo la misma luz; el carbono tiene trama estable sobre la superficie.
- Reproducir las zonas cromaticas principales y el numero de la referencia sin logotipos. Revisar ambas caras y vista superior.
- Revisar GLB exportado fuera del estudio y comprobar ausencia de geometria adicional coplanar por vinilos.
- Medir latencia de mover una capa y consumo GPU en la RTX 3050: ajustar resolucion interactiva, recomposicion de regiones afectadas y calidad final segun mediciones, sin fijar un limite arbitrario de capas por adelantado.
