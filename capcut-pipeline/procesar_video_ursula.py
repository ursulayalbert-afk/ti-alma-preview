"""
Pipeline TI - Procesado automatico de video bruto Ursula
Uso: python procesar_video_ursula.py <ruta_video.mp4>

Pasos:
1. Importa video a CapCut como nuevo draft
2. SmartCut elimina silencios >1s y tomas duplicadas
3. VectCutAPI aplica preset talking_head con parametros TI
4. Guarda draft en CapCut listo para revision de Albert

Nota: este script habla con VectCutAPI (puerto 9001). La fase de SmartCut
se ejecuta desde Claude Code/Desktop via el MCP "smartcut" una vez el draft
existe (ver README.md).
"""

import os
import sys

import requests

BASE_URL = os.environ.get("CAPCUT_API_URL", "http://localhost:9001")
VIDEO_PATH = sys.argv[1] if len(sys.argv) > 1 else None

# Parametros de marca TI para subtitulos
TI_SUBTITLE_STYLE = {
    "font_size": 52,
    "font_color": "#FFFFFF",
    "background_color": "#2C1A0E",
    "background_opacity": 0.75,
    "position": "bottom",
    "margin_bottom": 80,
}


def _basename(video_path):
    """Nombre de archivo robusto para rutas Windows o POSIX."""
    return os.path.basename(video_path.replace("\\", "/"))


def crear_draft_talking_head(video_path):
    """Crea draft CapCut con preset talking_head y estilo TI"""

    nombre = _basename(video_path)

    # 1. Crear proyecto 9:16 para Reels
    r = requests.post(
        f"{BASE_URL}/create_draft",
        json={
            "width": 1080,
            "height": 1920,
            "fps": 30,
            "name": f"TI_reel_{nombre}",
        },
    )
    r.raise_for_status()
    draft_id = r.json()["output"]["draft_id"]
    print(f"OK Draft creado: {draft_id}")

    # 2. Anadir video principal
    r = requests.post(
        f"{BASE_URL}/add_video",
        json={
            "draft_id": draft_id,
            "video_url": video_path,
            "volume": 1.0,
        },
    )
    r.raise_for_status()
    print("OK Video anadido")

    # 3. Guardar draft para abrir en CapCut
    r = requests.post(f"{BASE_URL}/save_draft", json={"draft_id": draft_id})
    r.raise_for_status()
    print(f"OK Draft guardado: {r.json()}")
    print("\n-> Abre CapCut para ver el draft y aplicar SmartCut desde Claude Code")
    return draft_id


if __name__ == "__main__":
    if not VIDEO_PATH:
        print("Uso: python procesar_video_ursula.py <ruta_video.mp4>")
        sys.exit(1)
    try:
        crear_draft_talking_head(VIDEO_PATH)
    except requests.exceptions.ConnectionError:
        print(
            f"ERROR: no se pudo conectar a VectCutAPI en {BASE_URL}.\n"
            "Verifica que capcut_server.py esta arrancado "
            "(tarea programada 'TI-VectCutAPI')."
        )
        sys.exit(2)
    except requests.exceptions.HTTPError as e:
        print(f"ERROR HTTP de VectCutAPI: {e}")
        sys.exit(3)
