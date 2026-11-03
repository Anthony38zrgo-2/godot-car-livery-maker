# Estudio de libreas Polyphony001

## Color base de carroceria

Abre un GLB `*_sin_casco_partes.glb`. Activa **Color base carroceria** o elige un color en el selector de esa fila (incluye entrada HEX). Selecciona Mate, Satinado, Brillante o Metalizado. El cambio sustituye los graficos originales de las superficies de carroceria identificadas por un color uniforme, debajo de la pintura del atlas. Desactivar la casilla recupera los materiales originales. La luz, toma de aire, superficies negras, neumaticos y conjuntos de rin conservan sus materiales.

Guardar/Abrir librea conserva el color base, su activacion y su acabado. Las libreas anteriores sin estos campos se abren con el material original. El color base forma parte del documento del estudio; todavia no se exporta un GLB pintado. El acabado por vinilo sigue pendiente. Los rines tienen controles separados, descritos abajo.

Ejecuta `..\iniciar-gpu-texture-painter.ps1` y selecciona **Abrir GLB**. Los cuatro coches preparados estÃƒÆ’Ã‚Â¡n en `extracted/cars/polyphony001/models`, uno dentro de cada carpeta `95-model-*`. Aunque conservan el nombre `sin_casco` para mantener sus rutas, no incluyen tampoco el cuerpo del piloto. Los GLB `*_piloto.glb` en `extracted/cars/polyphony001/helmets` contienen casco y cuerpo juntos, como mallas independientes, y se pueden abrir con el mismo botÃƒÆ’Ã‚Â³n. Los archivos `*_casco.glb` anteriores tambiÃƒÆ’Ã‚Â©n se conservan.

Arrastra con el botÃƒÆ’Ã‚Â³n izquierdo para pintar, con el derecho para orbitar, y usa la rueda para acercar o alejar. El selector de color incluye transparencia; el deslizador ajusta el tamaÃƒÆ’Ã‚Â±o del pincel.

El panel permite elegir proyecciÃƒÆ’Ã‚Â³n ortogonal o perspectiva, tamaÃƒÆ’Ã‚Â±o o FOV, distancia mÃƒÆ’Ã‚Â¡xima, desvanecimiento, sangrado mÃƒÆ’Ã‚Â­nimo y mÃƒÆ’Ã‚Â¡ximo, resoluciÃƒÆ’Ã‚Â³n, velocidad, color y una imagen para la forma del pincel. La casilla habilita o deshabilita la pintura; mantÃƒÆ’Ã‚Â©n pulsado el botÃƒÆ’Ã‚Â³n izquierdo para dibujar. En perspectiva se utiliza el FOV, y en ortogonal el tamaÃƒÆ’Ã‚Â±o.

El tamaÃƒÆ’Ã‚Â±o del atlas y el shader elegido se aplican al abrir un modelo o al pulsar **Aplicar atlas**. Esta ÃƒÆ’Ã‚Âºltima acciÃƒÆ’Ã‚Â³n recrea el atlas y borra la pintura actual despuÃƒÆ’Ã‚Â©s de pedir confirmaciÃƒÆ’Ã‚Â³n: guarda primero la librea si quieres conservarla. Para un shader personalizado, parte de `addons/gpu_texture_painter/overlay_shaders/overlay_template.gdshader` y conserva el protocolo de coordenadas y atlas del addon. El archivo del shader debe permanecer disponible en su ruta para reabrir una librea que lo use. Al abrir una librea, su EXR determina el tamaÃƒÆ’Ã‚Â±o del atlas.

**Guardar librea** crea un archivo JSON y un atlas EXR a su lado en `extracted/cars/polyphony001/liveries`. **Abrir librea** vuelve a cargar ambos junto con el GLB base. Conserva juntos el JSON y el EXR y no muevas el GLB base: el JSON guarda su ruta absoluta. El guardado es una capa de pintura editable, no un GLB con las texturas fusionadas.

Los archivos `.blend` originales no se modificaron. Los pilotos se separaron usando los materiales `Material_1` (132 caras) y `Material_2` (76 caras) de `body_lod0`. `export_polyphony_driver.py` genera los pilotos; `clean_polyphony_glb.py` retira el cuerpo del piloto y triÃƒÆ’Ã‚Â¡ngulos coincidentes de los GLB previamente preparados, conservando los datos UV. El script `prepare_polyphony.py` genera la etapa anterior a esta limpieza. La copia verificada previa estÃƒÆ’Ã‚Â¡ en `backup_antes_limpieza_20261102_234756`, y los informes de limpieza estÃƒÆ’Ã‚Â¡n en `preparacion_limpieza`. La limpieza elimina duplicados coincidentes detectados, no garantiza que desaparezcan todas las formas de parpadeo. Otros GLB requieren UV2 sin solapamientos para funcionar correctamente. Conviene revisar visualmente las cuatro variantes y las libreas guardadas previamente.

## Color y acabado de rines

Tres controles independientes, del centro hacia fuera: **Rin 1 - centro** (Material_31), **Rin 2 - anillo intermedio** (Material_30, originalmente dorado) y **Rin 3 - anillo exterior** (Material_29). Cada control tiene activacion, color HEX y acabado Mate, Satinado, Brillante o Metalizado. Se aplican a las cuatro ruedas; desactivar una fila recupera su material original. Las mascaras y zonas protegidas se conservan.

Los tres ajustes se guardan con la librea. Las libreas anteriores con dos zonas se convierten conservando su apariencia: el anterior exterior pasa a Rin 2; el anterior interior pasa a Rin 1 y Rin 3. Verificados los cuatro modelos y el guardado/reapertura. La exportacion a GLB de estos ajustes sigue pendiente.

## Bloqueos temporales de pintura

Las casillas **Bloquear aleron delantero**, **Bloquear aleron trasero** y **Bloquear bargeboards** se aplican al instante con el shader predeterminado. No recrean el atlas ni eliminan la pintura existente. Desmarcar permite volver a pintar. Los tres estados se guardan con la librea; documentos anteriores los abren desactivados.

Los bargeboards se reconocen por sus nodos Bargeboard_F094H. Los alerones integrados en la carroceria se filtran por las regiones espaciales de los cuatro Polyphony001 preparados (incluye un pequeño margen en la raiz trasera); estos limites no constituyen perfiles universales para otros coches. La capa visible se conserva incluso al bloquear: solo se invalida la escritura del pincel. Mientras haya un bloqueo, el sangrado del pincel se suprime internamente para impedir que invada texeles vecinos protegidos; los valores configurados vuelven a utilizarse al desbloquear todo. Un shader personalizado necesita implementar los mismos parametros de bloqueo para soportarlos.

Prueba GPU: se comprobaron muestras UV de los cuatro modelos con las tres casillas activas y se verifico que vuelven a recibir pintura al desactivarlas, junto con guardado y reapertura de los estados. Queda recomendada la revision visual de bordes al pintar desde ambos laterales.

## Vinilos por capas

1. Abre un coche `*_sin_casco_partes.glb` y pulsa **Vinilos por capas...**. La ventana se puede mover/redimensionar; mientras esta abierta, los ajustes generales se ocultan para dejar espacio al coche.
2. Elige la forma en la biblioteca y pulsa **Anadir / colocar**. Haz clic sobre una superficie pintable del coche. Un clic sobre una zona protegida o un componente bloqueado rechaza la colocacion.
3. Selecciona una capa en la lista o haz clic sobre ella en el coche. Con **Modo vinilos** activado, el boton izquierdo selecciona/arrastra vinilos en vez de pintar. Derecho orbita y la rueda acerca/aleja. Las vistas lateral y superior ayudan a alinear.
4. Modifica ancho y alto de manera independiente, giro, desplazamiento horizontal/vertical, color HEX/opacidad, borde y color del borde. Horizontal/Vertical fijan 0/90 grados. **Curvatura** controla las dos formas curvas deportivas; **Numero** controla los digitos 0-99. Para renombrar una capa, escribe su nombre y pulsa Enter.
5. **Duplicar** crea una copia editable. **Reflejar** crea una copia al otro lado del eje central del coche conservando la lectura de los numeros. **Subir** lleva la capa por delante y **Bajar** por detras. La lista va del fondo a la capa superior.
6. **Visible** oculta/muestra y **Bloquear capa** impide editarla. Cerrar la ventana vuelve al pincel y los ajustes generales. **Guardar librea** conserva la pila completa en el JSON junto con el EXR de la pintura manual.

La biblioteca incluye rectangulo, rectangulo redondeado, circulo, triangulo, trapecio, franja afinada, franja doble/triple, chevron, rayo, curva deportiva, barrido deportivo, cuadros y numeros geometricos. Las formas se generan por codigo y no incluyen patrocinadores ni fuentes externas.

Cada vinilo guarda su posicion, orientacion y superficie destino. La proyeccion sigue la geometria existente sin añadir caras coplanares al coche. La profundidad controla hasta donde alcanza la proyeccion alrededor del punto de anclaje: usa valores pequeños para evitar alcanzar superficies cercanas no deseadas. Curvas fuertes pueden requerir varias capas o recolocar el vinilo. Arrastrar adapta su marco a la nueva normal de la superficie.

Los bloqueos de componentes se incorporan al crear/editar el vinilo para recortar zonas protegidas sin ocultar las capas ya existentes al activar una casilla. Los vinilos solo se aplican a superficies de carroceria reconocidas; no a neumaticos, rines, luz, toma de aire ni conductos protegidos.

Limite actual: 64 capas por documento, shader predeterminado y atlas de formas de 2048x2048. Las formas quedan editables; el EXR guardado contiene el pincel, no una copia aplanada de los vinilos. Las libreas antiguas sin `vinyl_layers` se abren conservando su pintura raster. Los acabados por vinilo, deshacer/rehacer y exportar la composicion a GLB siguen pendientes.
