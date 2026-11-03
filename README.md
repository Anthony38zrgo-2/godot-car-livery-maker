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
- Guardar/reabrir libreas como JSON y atlas EXR con ajustes de materiales y bloqueos.

El guardado actual conserva rutas absolutas al GLB base y al shader personalizado. Mantén juntos el JSON y el EXR; trasladar el modelo requiere actualizar su ruta. La copia de pintura es raster: aún no hay vinilos vectoriales editables ni exportación del coche pintado a GLB.

## Compatibilidad de modelos

La pintura necesita UV2 sin solapamientos. Los controles de carrocería y rines reconocen nombres de nodos y materiales de las cuatro variantes Polyphony001 preparadas, no cualquier GLB automáticamente. Los bloqueos de alerones integrados usan regiones espaciales específicas de esos modelos y el shader predeterminado; los shaders personalizados necesitan implementar los mismos parámetros. Mientras hay bloqueos se suprime el sangrado para evitar invadir regiones vecinas.

Los coches, texturas extraídas, ISOs y libreas del usuario **no se distribuyen** con este código. Debes proporcionar tus propios modelos y sus permisos de uso. La licencia MIT del código no concede derechos sobre recursos de videojuegos externos.

## Documentación y herramientas

- [Uso detallado del estudio](LEEME-LIBREAS.md).
- [Plan del editor por capas](PLAN-EDITOR-VINILOS.md): propuesta; sus funciones pendientes no forman parte de la versión actual.
- Scripts Python: preparación, separación de piloto, limpieza y clasificación de las variantes locales. Revisa sus supuestos y conserva backups antes de usarlos con otros modelos.

La carga, materiales, máscaras, guardado y bloqueos se probaron mediante ejecución GPU y comprobaciones automatizadas. Es recomendable revisar visualmente cada variante y sus límites de pintura.
