# Pipeline CapCut TI — Edición automática vídeo Úrsula

> **Estado de la instalación:** los _artefactos_ del pipeline (script maestro,
> instalador PowerShell, snippet de config MCP y esta documentación) están
> versionados en este repo. La **instalación real** (clonar repos, crear venvs,
> arrancar `capcut_server.py`, tarea programada, registrar MCP en Claude Desktop
> y localizar la carpeta de drafts) **debe ejecutarse en el taller Windows**,
> porque requiere `C:\COMPARTIDO\Sauron\`, CapCut y `localhost:9001` — no
> accesibles desde el entorno cloud donde se generaron estos ficheros.
>
> **Para instalar en el taller:**
> ```powershell
> # Copia esta carpeta a C:\COMPARTIDO\Sauron\tools\capcut-pipeline\ y ejecuta:
> cd C:\COMPARTIDO\Sauron\tools\capcut-pipeline
> powershell -ExecutionPolicy Bypass -File .\install_pipeline.ps1
> ```
> El instalador hace los Bloques 1–3, la tarea programada, el merge de la config
> MCP (sin borrar entradas existentes) y localiza la carpeta de drafts.

## Flujo de trabajo
1. Úrsula graba vídeo bruto → guarda en `C:\COMPARTIDO\Sauron\videos\brutos\`
2. Albert ejecuta desde Claude Code:
   "Procesa el vídeo [nombre.mp4] con el pipeline CapCut TI"
3. Sauron: importa a CapCut, elimina silencios, corta duplicados, aplica estilo TI
4. Albert abre CapCut → revisa draft → ajustes manuales si necesario
5. Úrsula aprueba → exporta → publica

## Componentes instalados
- VectCutAPI: `C:\COMPARTIDO\Sauron\tools\capcut-pipeline\VectCutAPI\` (puerto 9001)
- capcut-mcp-server: `C:\COMPARTIDO\Sauron\tools\capcut-pipeline\capcut-mcp-server\`
- SmartCut: `C:\COMPARTIDO\Sauron\tools\capcut-pipeline\smartcut\`
- Script maestro: `procesar_video_ursula.py`

## Parámetros de marca TI (subtítulos)
- Fuente: 52px blanco sobre fondo `#2C1A0E` opacidad 75%
- Posición: inferior con margen 80px
- Formato salida: 1080x1920 (Reels/Stories), 30fps

## Aviso importante
SmartCut modifica el proyecto in-place. Siempre duplicar el draft
en CapCut antes de ejecutar SmartCut.

## Si VectCutAPI no arranca al inicio
Verificar tarea programada "TI-VectCutAPI" en Programador de tareas Windows.
Arrancar manualmente:
```
cd C:\COMPARTIDO\Sauron\tools\capcut-pipeline\VectCutAPI
venv-capcut\Scripts\python.exe capcut_server.py
```

---

## Verificación final (Bloque 5) — ejecutar en el taller
1. **VectCutAPI responde:** `curl http://localhost:9001` → JSON con info del servidor
2. **Test draft básico:**
   ```
   cd C:\COMPARTIDO\Sauron\tools\capcut-pipeline\VectCutAPI
   venv-capcut\Scripts\python.exe test_mcp_client.py
   ```
   → debe mostrar `✅ MCP server started successfully` y `✅ 11 available tools`
3. **Config MCP válida:** confirmar que `%APPDATA%\Claude\claude_desktop_config.json`
   tiene las entradas `capcut` y `smartcut` y es JSON válido. El instalador deja
   un backup `.bak` y valida el JSON tras escribir.
4. **Carpeta de drafts CapCut:** localizar con
   ```
   powershell -ExecutionPolicy Bypass -File .\install_pipeline.ps1 -FindDraftsOnly
   ```
   (busca recursivamente bajo `%LOCALAPPDATA%\CapCut\` carpetas `draft*` con `.json`).

## Ficheros de esta carpeta
- `procesar_video_ursula.py` — script maestro (Bloque 4)
- `install_pipeline.ps1` — instalador Windows (Bloques 1–3 + tarea + merge config + drafts)
- `claude_desktop_config.snippet.json` — entradas `capcut` + `smartcut` para merge manual
- `README.md` — este documento
