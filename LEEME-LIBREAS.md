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
