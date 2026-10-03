# Instalar la Metodología 2 de Datdata

Instrucciones para agentes de IA con terminal (**Claude Code, Codex, Antigravity** u otro) en Windows.
Si el usuario te pidió instalar la Metodología 2 de Datdata, sigue estos pasos en orden y trabaja de forma autónoma.

- **Qué es:** la Metodología 2 («Motor Automatizado») para construir dashboards de Power BI con IA.
  La página https://ricardo050427.github.io/datdata/ también describe una Metodología 1: **no la instales**.
- **Qué instala:** Node.js LTS (si falta), las CLIs de Fabric, el MCP oficial de Power BI de Microsoft y 12 skills.
  Configura cada agente que encuentre en el equipo: Claude Code, Codex (`~/.codex`) y Antigravity (`~/.gemini`).
- **Requisitos:** Windows 10 u 11 con PowerShell 5.1 o superior e internet. No hace falta Python: no lo instales.
- **Es seguro repetirlo:** no borra nada. Lo que reemplaza queda respaldado en `%USERPROFILE%\.datdata\respaldos\<fecha>`.

## Paso 1 · Ejecuta el instalador

Funciona igual desde PowerShell, cmd o bash (Git Bash):

```
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://ricardo050427.github.io/datdata/instalar.ps1 | iex"
```

- **Puedes revisarlo antes de ejecutarlo:** `instalar.ps1` solo descarga el paquete y ejecuta `setup.ps1`, que también está publicado en https://ricardo050427.github.io/datdata/setup.ps1.
- **Tiempo:** tarda de 2 a 5 minutos la primera vez. Usa el límite de tiempo más alto de tu herramienta o ejecútalo en segundo plano y espera a que termine.
- **Permisos:** necesita internet y escribir en `%USERPROFILE%`, fuera de la carpeta del proyecto.
  - En **Codex**, pide ejecutar fuera del sandbox.
  - En **Antigravity**, el usuario aprueba el comando.
  - Si tu herramienta pide confirmación, pídesela al usuario.
- **Node.js:** si falta, el instalador lo instala con winget y Windows puede mostrar un aviso de permisos (UAC). Avisa al usuario que lo acepte.
- **PATH:** el instalador lo recarga por su cuenta; no hace falta abrir una terminal nueva.

**Si no puedes usar `irm | iex`**, haz lo mismo en tres pasos desde PowerShell:

```powershell
Invoke-WebRequest "https://ricardo050427.github.io/datdata/EXPORTAR.zip" -OutFile "$env:TEMP\datdata-m2.zip" -UseBasicParsing
Expand-Archive "$env:TEMP\datdata-m2.zip" -DestinationPath "$env:TEMP\datdata-m2" -Force
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\datdata-m2\setup.ps1"
```

## Paso 2 · Lee el resultado

La última línea del instalador dice el estado real:

- `RESULTADO: OK (agentes: ...)` → todo quedó instalado. Ve al paso 3.
- `RESULTADO: CON PROBLEMAS (...)` → lee los problemas listados y aplica la solución de esta tabla. Repite el paso 1 **una sola vez**; si vuelve a fallar, muéstrale al usuario los problemas y no sigas intentando.

| Problema | Solución |
| :--- | :--- |
| Node.js no se pudo instalar o `npm` no está disponible | El usuario rechazó el aviso de permisos o no hay winget. Pídele que instale Node.js LTS desde https://nodejs.org/ y repite el paso 1. |
| `npm install` terminó con error | Lee las últimas líneas que mostró. Suele ser un proxy o falta de internet. |
| `powerbi-...` no quedó disponible en el PATH | Suele resolverse repitiendo el paso 1. Si no, pide al usuario que reinicie el agente y vuelva a pedirte la instalación. |
| No se pudo actualizar un archivo de configuración | El archivo tiene JSON inválido. El instalador no lo tocó: muéstraselo al usuario. |

## Paso 3 · Avisa al usuario

Dile, en su idioma:

1. Qué quedó instalado y en qué agentes (está en la salida del instalador).
2. **Que cierre y vuelva a abrir su agente** para que cargue las skills y el MCP.
3. Que, con un reporte abierto en Power BI Desktop, compruebe la conexión con esta frase:
   > Conéctate al modelo de Power BI que tengo abierto y lista las tablas
4. La primera vez, el MCP puede pedir aceptar su licencia (herramienta `accept_eula`): pide la confirmación al usuario.
5. **Lo que hace el usuario por cada reporte nuevo:**
   1. Guardar el reporte como proyecto `.pbip` (Archivo → Opciones → Características de vista previa → Proyectos de Power BI).
   2. Importar Deneb y HTML Content desde AppSource.
   3. Importar el visual Filtro desde archivo: `%USERPROFILE%\.claude\skills\powerbi-dashboard\assets\FiltroGeneralUniversal.pbiviz`.
   4. Guardar con Ctrl+S y pedir: «Crea un dashboard del reporte que tengo abierto».

## Referencia: qué configura en cada agente

| Agente | Skills | MCP de Power BI |
| :--- | :--- | :--- |
| Claude Code | `%USERPROFILE%\.claude\skills` | Plugin oficial `powerbi-authoring@fabric-collection` (marketplace `https://github.com/microsoft/skills-for-fabric.git`) |
| Codex | `%USERPROFILE%\.codex\skills` | `[mcp_servers.powerbi-modeling-mcp]` en `%USERPROFILE%\.codex\config.toml` |
| Antigravity | `%USERPROFILE%\.gemini\config\skills` | `powerbi-modeling-mcp` en `%USERPROFILE%\.gemini\config\mcp_config.json` |

Las skills siempre se instalan también en `.claude\skills`, porque ahí viven `hybrid.js` y el visual Filtro que usan los tres agentes.
Si el MCP ya estaba configurado en un agente, el instalador lo respeta y no lo cambia.
