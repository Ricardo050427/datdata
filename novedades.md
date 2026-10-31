# Novedades de la Metodología 2

## 2.1.2 · 31 de octubre de 2026

- **El lienzo se queda en 1440×1080** mientras no pidas otro tamaño. Antes el agente podía cambiarlo por su cuenta, por ejemplo a 1600×900 en un dashboard de una sola página.
- **Los dashboards que ya tienes no cambian:** al modificarlos, el agente conserva su lienzo.

## 2.1.1 · 17 de octubre de 2026

- **Las tarjetas ya no salen en blanco con HTML Content Secure.** `hybrid.js` revisa qué visuales tiene importados el reporte y usa ese: HTML Content normal o Secure (antes «lite»), y el filtro clásico o el Filtro Universal+.
- **Si importaste los dos filtros,** el dashboard usa el clásico, como hasta ahora. Para usar el Filtro Universal+ en un dashboard, impórtalo solo a él o pídeselo a tu agente.

## 2.1.0 · 17 de octubre de 2026

- **Nuevo visual Filtro Universal+** (`FiltroUniversal+.pbiviz`), junto al filtro de siempre:
  - 5 estilos: Contorno, Píldoras, Suave, Subrayado y Segmentado.
  - Tamaño de letra, alto de los botones, alineación, redondez, separación y colores, desde el panel de formato.
  - Horizontal o vertical, cuántos campos se ven antes de «+ Más filtros» y botones del mismo ancho.
  - Selección única o múltiple, buscador configurable y botón «Limpiar» opcional.
  - Recuerda la selección al guardar el reporte y con los marcadores.
  - Lee las mismas propiedades que escribe `hybrid.js` (tamaño de letra, alineación y color de acento).
- **El Filtro General Universal sigue incluido**, sin cambios: los reportes que ya lo usan no se afectan.
- **El instalador muestra la versión** que tenías, la que se instala y estas novedades.
