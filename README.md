# Godot Car Livery Maker

Editor de pintura de coches en Godot, derivado de **Godot GPU Texture Painter**, creado por **Anton Hörig (maantho)**.

## Autor original y licencia

El sistema de pintura GPU, CameraBrush y OverlayAtlasManager procede de [maantho/gpu-texture-painter](https://github.com/maantho/gpu-texture-painter). Su autor original es **Anton Hörig**, copyright 2025. Este repositorio conserva su historial, atribución y licencia [MIT](LICENSE), también incluida en [el addon](addons/gpu_texture_painter/LICENSE). La documentación original se conserva en [README-UPSTREAM.md](README-UPSTREAM.md).

Las adaptaciones de este repositorio añaden el estudio de libreas, carga externa de modelos, materiales base, controles de rines y protección de superficies. Las imágenes de demostración del addon pertenecen al proyecto original.

## Requisitos y arranque

- Godot 4.7 o superior; probado con 4.7.1 en Windows y una NVIDIA RTX 3050.
- Renderer Forward+ y GPU compatible con compute shaders; no utilizar Compatibility.
- PowerShell para el lanzador opcional. Python y Blender solo son necesarios para preparar modelos, no para ejecutar el editor.

Abre `project.godot` en Godot y ejecuta el proyecto, o utiliza:

```powershell
.\iniciar.ps1 -GodotPath 'C:\ruta\Godot.exe'
```

También detecta `GODOT_BIN` o Godot en PATH. Para abrir el editor:

```powershell
.\iniciar.ps1 -Editor
```

Después selecciona **Abrir GLB**. Puedes navegar a cualquier carpeta del equipo. La carpeta sugerida es `../extracted/cars/polyphony001/models` respecto al proyecto; el guardado propone `../extracted/cars/polyphony001/liveries`.

## Funciones disponibles

- Cargar GLB externos, orbitar con botón derecho y acercar con la rueda.
- Pintar con botón izquierdo; elegir color, forma de pincel, proyección, tamaño/FOV, resolución, velocidad y sangrado.
- Elegir color base de carrocería y acabado mate, satinado, brillante o metalizado.
- Configurar tres zonas del rin: centro, anillo intermedio y anillo exterior, con color y acabado independientes.
- Excluir superficies identificadas con prefijo `NO_PINTAR_`.
- Bloquear temporalmente alerón delantero, trasero y bargeboards sin borrar pintura existente.
- Vinilos editables por capas: formas simples, franjas deportivas, curvas, chevrons, rayos, cuadros y numeros 0-99.
- Colocacion directa sobre superficies pintables; seleccion, arrastre, giro, ancho/alto independientes, bordes, duplicado, reflejo y orden de capas.
- Guardar/reabrir libreas como JSON y atlas EXR con capas, ajustes de materiales y bloqueos.
- Exportar un atlas completo PNG o EXR de color, con superficies protegidas y un JSON de mapeo UV2.

El guardado actual conserva rutas absolutas al GLB base y al shader personalizado. Mantén juntos el JSON y el EXR; trasladar el modelo requiere actualizar su ruta. El pincel se guarda como pintura raster; los vinilos se guardan como parametros editables y se recomponen al abrir. Todavia no hay exportacion del coche pintado a GLB. Los vinilos requieren el shader predeterminado y admiten hasta 64 capas por documento.

## Compatibilidad de modelos

La pintura necesita UV2 sin solapamientos. Los controles de carrocería y rines reconocen nombres de nodos y materiales de las cuatro variantes Polyphony001 preparadas, no cualquier GLB automáticamente. Los bloqueos de alerones integrados usan regiones espaciales específicas de esos modelos y el shader predeterminado; los shaders personalizados necesitan implementar los mismos parámetros. Mientras hay bloqueos se suprime el sangrado para evitar invadir regiones vecinas.

Los coches, texturas extraídas, ISOs y libreas del usuario **no se distribuyen** con este código. Debes proporcionar tus propios modelos y sus permisos de uso. La licencia MIT del código no concede derechos sobre recursos de videojuegos externos.

## Documentación y herramientas

- [Uso detallado del estudio](LEEME-LIBREAS.md).
- [Plan del editor por capas](PLAN-EDITOR-VINILOS.md): propuesta; sus funciones pendientes no forman parte de la versión actual.
- Scripts Python: preparación, separación de piloto, limpieza y clasificación de las variantes locales. Revisa sus supuestos y conserva backups antes de usarlos con otros modelos.

La carga, materiales, máscaras, guardado y bloqueos se probaron mediante ejecución GPU y comprobaciones automatizadas. Es recomendable revisar visualmente cada variante y sus límites de pintura.

## Pruebas de vinilos

Despues de importar el proyecto en Godot, ejecuta `Godot --path . --script res://tests/test_vinyl_layers.gd`. Usa geometria sintetica y no necesita los coches extraidos. Comprueba formas y numeros, superficies protegidas, transformaciones, duplicado/reflejo/orden, renderizado GPU, serializacion y reutilizacion de texturas al mover capas.

## Exportar el atlas completo

Selecciona **Exportar atlas** y guarda en PNG o EXR. El atlas combina el albedo de los materiales actuales, color base, rines, pintura del pincel y vinilos visibles. Tambien incorpora las piezas protegidas, conservando su apariencia base. Los acabados (rugosidad y metalicidad) no se codifican en esta imagen de color.

La exportacion reorganiza las piezas para incluir las que no tienen espacio en el atlas de pintura. El archivo `*_mapeo.json` acompana a la imagen y proporciona `position` y `size` para cada nodo: `UV_atlas = UV2 * size + position`. El PNG/EXR por si solo no actualiza los UV del GLB ni es una exportacion de modelo. Este atlas aplanado no sustituye el documento editable JSON + EXR de pintura. La exportacion requiere el shader predeterminado, UV2 en todas las piezas y renderizado GPU. El EXR se genera desde la imagen del viewport, no es un atlas HDR de alta precision.
