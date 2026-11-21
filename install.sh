#!/usr/bin/env bash
# =====================================================================
#  DNX Profil-Sortierung  v1.0.1  -  Installation / Deinstallation
# ---------------------------------------------------------------------
#  Benutzung:
#     sudo ./install.sh install      einbauen
#     sudo ./install.sh update       neu einbauen (alte Fassung ersetzen)
#     sudo ./install.sh status       pruefen, ob es eingebaut ist
#     sudo ./install.sh uninstall    restlos entfernen
#
#  --- Drei Wege, das Plugin-Verzeichnis zu finden ---------------------
#
#  1) Direkt angeben (kein Docker noetig - z. B. Installation aus den
#     Paketquellen oder von Hand):
#        sudo PLUGINS=/pfad/zu/plugins ./install.sh install
#     Dort muss <pfad>/receiver/init.js liegen.
#
#  2) Docker-Container (wie bisher). Der Mountpunkt wird aus dem
#     Container gelesen, Voreinstellung owrx-8013:
#        sudo CONTAINER=owrx-8011 ./install.sh install
#
#  3) Nichts angegeben: es werden die ueblichen Pfade durchgesehen
#     (/opt/owrx-docker/plugins, .../dist-packages/htdocs/plugins,
#     /opt/openwebrx/htdocs/plugins).
#
#  Ohne Neustart (nur Browser neu laden):
#     sudo NORESTART=1 ./install.sh install
#
#  Es wird ausschliesslich an zwei Stellen gearbeitet:
#     <plugins>/receiver/dnx_profil_sort.js   (die Sortierung)
#     <plugins>/receiver/init.js              (ein eigener Loader-Block,
#                                               Marke DNX_PROFIL_SORT_*)
#  Alles andere bleibt unberuehrt. Vor jedem Eingriff wird von init.js
#  ein Backup unter /opt/dnx-ft8-beobachten-backups/<Zeitpunkt>/ abgelegt.
#
#  Private, inoffizielle Hobby-Anpassung; kein offizielles
#  OpenWebRX-/OpenWebRX+-Projekt. Nutzung auf eigene Gefahr.
# =====================================================================
set -Eeuo pipefail

CMD=${1:-install}
C=${CONTAINER:-owrx-8013}
NORESTART=${NORESTART:-0}
HERE=$(cd "$(dirname "$0")" && pwd)
BACK=/opt/dnx-profil-sortierung-backups
DATEI=dnx_profil_sort.js
MARK_A="/* DNX_PROFIL_SORT_START */"
MARK_B="/* DNX_PROFIL_SORT_END */"

I=""          # Pfad zur init.js
S=""          # Pfad zum Plugin-Verzeichnis
ART=""        # wie das Verzeichnis gefunden wurde
CONT=""       # genutzter Container (leer = keiner)

# --- 1) direkt vorgegeben? --------------------------------------------
suche_vorgabe() {
  [ -n "${PLUGINS:-}" ] || return 1
  S="$PLUGINS"
  I="$S/receiver/init.js"
  [ -f "$I" ] || { echo "FEHLER: $I nicht gefunden. PLUGINS zeigt auf das Verzeichnis, in dem 'receiver/init.js' liegt." >&2; exit 1; }
  ART="vorgegeben (PLUGINS)"
  return 0
}

# --- 2) aus einem Docker-Container ------------------------------------
suche_docker() {
  command -v docker >/dev/null 2>&1 || return 1
  docker inspect "$C" >/dev/null 2>&1 || return 1
  local m
  m=$(docker inspect "$C" --format '{{range .Mounts}}{{if eq .Destination "/usr/lib/python3/dist-packages/htdocs/plugins"}}{{.Source}}{{end}}{{end}}')
  [ -n "$m" ] || return 1
  S="$m"
  I="$S/receiver/init.js"
  [ -f "$I" ] || return 1
  ART="Docker-Container $C"
  CONT="$C"
  return 0
}

# --- 3) uebliche Pfade ------------------------------------------------
suche_standard() {
  local k
  for k in /opt/owrx-docker/plugins \
           /usr/lib/python3/dist-packages/htdocs/plugins \
           /usr/local/lib/python3/dist-packages/htdocs/plugins \
           /usr/lib/python3.11/dist-packages/htdocs/plugins \
           /usr/lib/python3.12/dist-packages/htdocs/plugins \
           /usr/lib/python3.13/dist-packages/htdocs/plugins \
           /opt/openwebrx/htdocs/plugins \
           /opt/openwebrx+/htdocs/plugins \
           /srv/openwebrx/htdocs/plugins ; do
    if [ -f "$k/receiver/init.js" ]; then
      S="$k"; I="$S/receiver/init.js"; ART="Standardpfad"; return 0
    fi
  done
  return 1
}

# --- Plugin-Verzeichnis ermitteln -------------------------------------
pfade() {
  suche_vorgabe  || suche_docker || suche_standard || {
    echo "FEHLER: Plugin-Verzeichnis nicht gefunden." >&2
    echo "        So geht es weiter:" >&2
    echo "          sudo PLUGINS=/pfad/zu/plugins $0 $CMD      (direkt, ohne Docker)" >&2
    echo "          sudo CONTAINER=mein-container $0 $CMD      (Mountpunkt aus Docker)" >&2
    exit 1
  }
  echo "  Verzeichnis: $S  ($ART)"
}

# --- Loader-Block wieder herausnehmen ----------------------------------
heraus() {
  [ -f "$I" ] || return 0
  if grep -qF "$MARK_A" "$I" 2>/dev/null; then
    # Der Block wird herausgenommen - und die Leerzeile davor gleich mit,
    # damit danach genau wieder der alte Inhalt drinsteht.
    awk -v a="$MARK_A" -v b="$MARK_B" '
      index($0,a){f=1; if(prev==""){prev=""} next}
      index($0,b){f=0; next}
      f{next}
      { if(prev!="") print prev; prev=$0 }
      END{ if(!f && prev!="") print prev }
    ' "$I" > "$I.dnx-neu" && mv -f "$I.dnx-neu" "$I"
  fi
  rm -f "$I.dnx-neu"
}

# --- Empfaenger neu starten (nur wenn es etwas zu starten gibt) --------
neu_starten() {
  if [ "$NORESTART" = "1" ]; then
    echo "  kein Neustart (NORESTART=1) - im Browser einmal neu laden (Strg+F5)."
    return 0
  fi
  if [ -n "$CONT" ] && command -v docker >/dev/null 2>&1; then
    docker restart "$CONT" >/dev/null && echo "  Container '$CONT' neu gestartet."
    echo "  Bitte 60-90 Sekunden warten, dann Browser neu laden (Strg+F5)."
    return 0
  fi
  if command -v systemctl >/dev/null 2>&1; then
    local d
    for d in openwebrx openwebrx-plus owrx openwebrx@owrx; do
      if systemctl list-unit-files "$d.service" >/dev/null 2>&1; then
        systemctl restart "$d" >/dev/null 2>&1 && { echo "  Dienst '$d' neu gestartet."; return 0; }
      fi
    done
  fi
  echo "  Hinweis: ohne Docker/Systemd nicht neu gestartet -"
  echo "           Empfaenger-Dienst von Hand neu starten oder Browser Strg+F5."
  return 0
}

install() {
  [ "$(id -u)" -eq 0 ] || { echo "FEHLER: bitte mit sudo (oder als root) aufrufen." >&2; exit 1; }
  pfade
  [ -f "$HERE/files/$DATEI" ] || { echo "FEHLER: $HERE/files/$DATEI fehlt." >&2; exit 1; }

  local T; T=$(date +%F-%H%M%S)
  mkdir -p "$BACK/$T"
  cp -a "$I" "$BACK/$T/init.js"
  echo "  Backup: $BACK/$T/init.js"

  local vorher="weg"
  grep -qF "$MARK_A" "$I" 2>/dev/null && vorher="da"
  heraus
  cp -f "$HERE/files/$DATEI" "$S/receiver/$DATEI"
  cat >> "$I" <<JS

$MARK_A
(function(){
  if (document.getElementById("dnx-profil-sort-script")) return;
  var s = document.createElement("script");
  s.id = "dnx-profil-sort-script";
  s.async = false;
  s.src = "static/plugins/receiver/$DATEI?v=" + Date.now();
  (document.head || document.documentElement).appendChild(s);
})();
$MARK_B
JS
  echo "  eingebaut in: $S/receiver/$DATEI"
  neu_starten
  [ "$vorher" = "da" ] && echo "  (alte Fassung ersetzt)" || true
  echo "Fertig: installiert."
}

uninstall() {
  [ "$(id -u)" -eq 0 ] || { echo "FEHLER: bitte mit sudo (oder als root) aufrufen." >&2; exit 1; }
  pfade
  local T; T=$(date +%F-%H%M%S)
  mkdir -p "$BACK/$T"
  cp -a "$I" "$BACK/$T/init.js"
  heraus
  rm -f "$S/receiver/$DATEI"
  echo "  Backup:   $BACK/$T/init.js"
  echo "  entfernt: $S/receiver/$DATEI"
  neu_starten
  echo "Fertig: restlos entfernt."
}

status() {
  pfade
  if grep -qF "$MARK_A" "$I" 2>/dev/null; then
    echo "installiert (Loader in $I)"
  else
    echo "nicht installiert"
  fi
  if [ -f "$S/receiver/$DATEI" ]; then
    echo "Datei da: $S/receiver/$DATEI"
  else
    echo "Datei fehlt: $S/receiver/$DATEI"
  fi
  if [ -d "$BACK" ]; then
    echo "Backups: $(ls -1 "$BACK" | wc -l) Stueck unter $BACK"
  fi
}

case "$CMD" in
  install|update) install ;;
  uninstall)      uninstall ;;
  status)         status ;;
  *) echo "Benutzung: $0 install | update | status | uninstall" ; exit 1 ;;
esac
