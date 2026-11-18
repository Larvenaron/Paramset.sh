#!/usr/bin/env bash
# Pflegt Parameter in der hardcodierten IDMC-Parameterdatei ps_Global.params
# (GLOBAL- und Taskflow-Sections).

set -euo pipefail

SCRIPT_NAME=$(basename "$0")

PARAMS_FILE="/home/Larve/IDMC/Paramsetcli/EDWH_Paramset-example/ps_Global.params"

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME -a <add|delete> -s <Global|Taskflow> -pn <Parametername> -pv <Parameterwert> [-p <Projekt> -f <Folder> -tfn <Taskflowname>] [-force]

  -a       Aktion: add oder delete (mandatory), Langform: -action
  -s       Section-Typ: Global oder Taskflow (mandatory)
  -p       Projekt in der IDMC (mandatory bei -s Taskflow)
  -f       Folder in der IDMC (mandatory bei -s Taskflow)
  -tfn     Vollständiger Taskflowname (mandatory bei -s Taskflow)
  -pn      Parametername, z.B. MyParam; das \$\$-Präfix ergänzt das Skript (mandatory)
  -pv      Parameterwert (mandatory)
  -force   Nur bei -a add: abweichenden Parameterwert ohne Rückfrage überschreiben
  -h       Diese Hilfe

Zieldatei (hardcodiert): $PARAMS_FILE
Section-Header für Taskflows: [Projekt].[Folder].[Taskflow]
Das \$\$-Präfix des Parameternamens wird automatisch ergänzt.
Vor jeder Änderung wird eine Sicherungskopie '$PARAMS_FILE.bak' erstellt.

Wichtig: -pn und -pv immer quotiert übergeben. Ein unquotiertes \$\$ wird von der
Shell durch ihre Prozess-ID ersetzt (aus -pn \$\$Name wird -pn 2048Name).
Richtig: -pn MyParam   oder   -pn '\$\$MyParam'
Falsch:  -pn \$\$MyParam
EOF
}

SECTION=""
PROJECT=""
FOLDER=""
TFN=""
PNAME=""
PVALUE=""
ACTION=""
FORCE=0

while [[ $# -gt 0 ]]; do
  OPT="$1"
  case "$OPT" in
    -force)
      FORCE=1
      shift
      continue
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -s|-p|-f|-tfn|-pn|-pv|-a|-action)
      if [[ $# -lt 2 ]]; then
        echo "Fehler: Option '$OPT' erwartet einen Wert." >&2
        exit 1
      fi
      OPT_VALUE="$2"
      shift 2
      ;;
    *)
      echo "Unbekannte Option: $OPT" >&2
      echo 'Hinweis: Enthält -pn oder -pv unquotiert Leerzeichen oder Sonderzeichen, zerfällt der Wert in mehrere Argumente. Bitte -pn und -pv in Anführungszeichen setzen.' >&2
      usage >&2
      exit 1
      ;;
  esac
  case "$OPT" in
    -s) SECTION="$OPT_VALUE" ;;
    -p) PROJECT="$OPT_VALUE" ;;
    -f) FOLDER="$OPT_VALUE" ;;
    -tfn) TFN="$OPT_VALUE" ;;
    -pn) PNAME="$OPT_VALUE" ;;
    -pv) PVALUE="$OPT_VALUE" ;;
    -a|-action) ACTION="$OPT_VALUE" ;;
  esac
done

# -pn und -pv werden zuerst geprüft, damit Fehler durch fehlende Anführungszeichen
# früh und klar sichtbar sind. Die Shell entfernt die Quotes vor dem Skriptstart,
# erkennbar sind nur ihre Folgen (z. B. die $$-Prozess-ID-Expansion).

if [[ -z "$PNAME" ]]; then
  echo "Fehler: -pn (Parametername) ist mandatory." >&2
  echo 'Hinweis: Ist -pn leer, hat die Shell vermutlich einen unquotierten Wert expandiert. Bitte -pn quotiert übergeben.' >&2
  exit 1
fi

if [[ -z "$PVALUE" ]]; then
  echo "Fehler: -pv (Parameterwert) ist mandatory." >&2
  echo 'Hinweis: Ist -pv leer, hat die Shell vermutlich einen unquotierten Wert expandiert. Bitte -pv quotiert übergeben.' >&2
  exit 1
fi

# $$-Präfix des Parameternamens automatisch ergänzen (führende $ werden entfernt).
while [[ "$PNAME" == '$'* ]]; do
  PNAME="${PNAME:1}"
done

# Gültiger Name: beginnt mit Buchstabe oder Unterstrich, danach Buchstaben, Ziffern, _ . -
# Ein unquotiert übergebenes $$ wird von der Shell durch ihre Prozess-ID ersetzt und
# erzeugt Namen wie 2048DBConnection_DWH - genau dieser Fall wird hier abgefangen.
if [[ ! "$PNAME" =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]]; then
  echo "Fehler: Ungültiger Parametername '$PNAME' - -pn wurde vermutlich nicht quotiert übergeben." >&2
  if [[ "$PNAME" =~ ^[0-9]+ ]]; then
    echo "Ursache: Ein unquotiertes \$\$ in -pn wird von der Shell durch ihre Prozess-ID ersetzt, aus -pn \$\$DBConnection_DWH wird so -pn 2048DBConnection_DWH." >&2
  fi
  echo "Bitte den Parameternamen ohne \$\$-Präfix übergeben (-pn DBConnection_DWH) oder quoten (-pn '\$\$DBConnection_DWH')." >&2
  exit 1
fi
PNAME="\$\$${PNAME}"
NEW_PARAM_LINE="${PNAME}=${PVALUE}"

SECTION_LC=$(printf '%s' "$SECTION" | tr '[:upper:]' '[:lower:]')
if [[ "$SECTION_LC" != "global" && "$SECTION_LC" != "taskflow" ]]; then
  echo "Fehler: -s muss 'Global' oder 'Taskflow' sein." >&2
  exit 1
fi

ACTION_LC=$(printf '%s' "$ACTION" | tr '[:upper:]' '[:lower:]')
if [[ "$ACTION_LC" != "add" && "$ACTION_LC" != "delete" ]]; then
  echo "Fehler: -a/-action muss 'add' oder 'delete' sein." >&2
  exit 1
fi

if [[ "$SECTION_LC" == "taskflow" ]]; then
  if [[ -z "$PROJECT" || -z "$FOLDER" || -z "$TFN" ]]; then
    echo "Fehler: -p, -f und -tfn sind mandatory, wenn -s Taskflow ist." >&2
    exit 1
  fi
fi

if [[ "$FORCE" -eq 1 && "$ACTION_LC" != "add" ]]; then
  echo "Fehler: -force ist nur in Kombination mit -a add erlaubt." >&2
  exit 1
fi

if [[ ! -f "$PARAMS_FILE" ]]; then
  echo "Fehler: Parameterdatei '$PARAMS_FILE' wurde nicht gefunden." >&2
  exit 1
fi

if [[ "$SECTION_LC" == "global" ]]; then
  HEADER="[GLOBAL]"
else
  HEADER="[${PROJECT}].[${FOLDER}].[${TFN}]"
fi

# Globale Arbeitsdaten: Zeilen der Datei.
LINES=()
# 1 = Datei verwendet Windows-Zeilenumbrüche (CRLF), 0 = Unix (LF).
# Das erkannte Format wird beim Zurückschreiben beibehalten.
FILE_CRLF=0

# Liest die Datei in LINES ein. CRLF wird erkannt und bereinigt,
# das Zeilenenden-Format bleibt beim Zurückschreiben erhalten.
load_file() {
  local file="$1" i
  FILE_CRLF=0
  mapfile -t LINES < "$file"
  for ((i = 0; i < ${#LINES[@]}; i++)); do
    if [[ "${LINES[i]}" == *$'\r' ]]; then
      FILE_CRLF=1
      LINES[i]="${LINES[i]%$'\r'}"
    fi
  done
}

# Schreibt LINES mit dem ursprünglichen Zeilenenden-Format zurück in die Datei.
save_file() {
  local file="$1"
  if [[ ${#LINES[@]} -eq 0 ]]; then
    : > "$file"
  elif [[ "$FILE_CRLF" -eq 1 ]]; then
    printf '%s\r\n' "${LINES[@]}" > "$file"
  else
    printf '%s\n' "${LINES[@]}" > "$file"
  fi
}

# Erstellt vor jeder Änderung eine Sicherungskopie der Datei.
make_backup() {
  local file="$1"
  cp -p "$file" "${file}.bak"
  echo "Sicherungskopie '${file}.bak' erstellt."
}

# Section-Header sind Zeilen der Form "[...]".
is_section_header() {
  [[ "$1" == \[*\] ]]
}

# Sucht die Section mit exakt dem übergebenen Header und setzt SEC_START/SEC_END
# (SEC_END = Index des nächsten Section-Headers oder Dateiende).
# Rückgabe 1, wenn die Section nicht existiert.
find_section() {
  local header="$1" n=${#LINES[@]} i
  SEC_START=-1
  SEC_END=$n
  for ((i = 0; i < n; i++)); do
    if [[ "${LINES[i]}" == "$header" ]]; then
      SEC_START=$i
      break
    fi
  done
  [[ $SEC_START -ge 0 ]] || return 1
  for ((i = SEC_START + 1; i < n; i++)); do
    if is_section_header "${LINES[i]}"; then
      SEC_END=$i
      break
    fi
  done
  return 0
}

# Sucht innerhalb [SEC_START+1, SEC_END) die erste Zeile, die mit "$PNAME=" beginnt.
# Setzt PARAM_IDX (-1 = nicht gefunden) und PARAM_IS_IDENTICAL (1 = Name und Wert identisch).
find_param_in_section() {
  local i
  PARAM_IDX=-1
  PARAM_IS_IDENTICAL=0
  for ((i = SEC_START + 1; i < SEC_END; i++)); do
    if [[ "${LINES[i]}" == "$PNAME="* ]]; then
      PARAM_IDX=$i
      if [[ "${LINES[i]}" == "$NEW_PARAM_LINE" ]]; then
        PARAM_IS_IDENTICAL=1
      fi
      break
    fi
  done
}

do_add() {
  if ! find_section "$HEADER"; then
    if [[ "$SECTION_LC" == "global" ]]; then
      echo "Fehler: Section $HEADER wurde in '$PARAMS_FILE' nicht gefunden." >&2
      exit 1
    fi
    # Taskflow-Section existiert nicht: am Dateiende neu anlegen.
    while [[ ${#LINES[@]} -gt 0 ]] && [[ -z "${LINES[-1]//[[:space:]]/}" ]]; do
      unset 'LINES[-1]'
    done
    LINES+=("" "$HEADER" "$NEW_PARAM_LINE")
    make_backup "$PARAMS_FILE"
    save_file "$PARAMS_FILE"
    echo "Section $HEADER existierte nicht und wurde am Ende der Datei angelegt."
    echo "Parameter '$NEW_PARAM_LINE' wurde in Section $HEADER angehängt."
    return 0
  fi

  find_param_in_section

  if [[ $PARAM_IS_IDENTICAL -eq 1 ]]; then
    echo "Der Parameter '$PNAME' existiert in Section $HEADER bereits genau so wie angegeben, es wurde nichts geändert."
    return 0
  fi

  if [[ $PARAM_IDX -ge 0 ]]; then
    # Parameter vorhanden, aber mit anderem Wert.
    local old_value="${LINES[PARAM_IDX]#*=}"
    if [[ $FORCE -eq 0 ]]; then
      echo "Der Parameter -pn \"$PNAME\" existiert in der angegebenen Section $HEADER bereits, weist aber den Wert -pv \"$old_value\" auf und nicht den Wert \"$PVALUE\" wie im Aufruf beschrieben." >&2
      echo "Wenn Sie diesen überschreiben möchten, fügen Sie Ihrem letzten Command bitte ein -force hinzu und führen Sie ihn erneut aus." >&2
      exit 1
    fi
    LINES[PARAM_IDX]="$NEW_PARAM_LINE"
    make_backup "$PARAMS_FILE"
    save_file "$PARAMS_FILE"
    echo "Parameter '$PNAME' wurde in Section $HEADER mit -force von '$old_value' auf '$PVALUE' überschrieben."
    return 0
  fi

  # Neuer Parameter: hinter die letzte nicht-leere Zeile der Section anhängen.
  local insert_at=$((SEC_START + 1)) i
  for ((i = SEC_START + 1; i < SEC_END; i++)); do
    if [[ -n "${LINES[i]//[[:space:]]/}" ]]; then
      insert_at=$((i + 1))
    fi
  done
  LINES=("${LINES[@]:0:insert_at}" "$NEW_PARAM_LINE" "${LINES[@]:insert_at}")
  make_backup "$PARAMS_FILE"
  save_file "$PARAMS_FILE"
  echo "Parameter '$NEW_PARAM_LINE' wurde an Section $HEADER angehängt."
}

do_delete() {
  if ! find_section "$HEADER"; then
    echo "Der Parameter '$PNAME' existiert nicht, keine Aktion wird durchgeführt."
    return 0
  fi

  find_param_in_section

  if [[ $PARAM_IDX -lt 0 ]]; then
    echo "Der Parameter '$PNAME' existiert nicht, keine Aktion wird durchgeführt."
    return 0
  fi

  if [[ $PARAM_IS_IDENTICAL -eq 0 ]]; then
    local old_value="${LINES[PARAM_IDX]#*=}"
    echo "Fehler: Der Parameter '$PNAME' existiert in der angegebenen Section $HEADER, weist aber einen anderen Value ('$old_value') auf. Bitte kontrollieren Sie den Aufruf." >&2
    exit 1
  fi

  # Prüfen, ob nach dem Löschen weitere Parameter in der Section bleiben.
  local i others=0
  for ((i = SEC_START + 1; i < SEC_END; i++)); do
    if [[ $i -ne $PARAM_IDX ]] && [[ -n "${LINES[i]//[[:space:]]/}" ]]; then
      others=1
      break
    fi
  done

  if [[ $others -eq 1 ]]; then
    LINES=("${LINES[@]:0:PARAM_IDX}" "${LINES[@]:$((PARAM_IDX + 1))}")
    make_backup "$PARAMS_FILE"
    save_file "$PARAMS_FILE"
    echo "Parameter '$NEW_PARAM_LINE' wurde aus Section $HEADER gelöscht."
  else
    # Letzter Parameter der Section: Section inklusive Header entfernen.
    local rem_start=$SEC_START
    if [[ $rem_start -gt 0 ]] && [[ -z "${LINES[$((rem_start - 1))]//[[:space:]]/}" ]]; then
      rem_start=$((rem_start - 1))
    fi
    LINES=("${LINES[@]:0:rem_start}" "${LINES[@]:$SEC_END}")
    make_backup "$PARAMS_FILE"
    save_file "$PARAMS_FILE"
    echo "Parameter '$NEW_PARAM_LINE' wurde aus Section $HEADER gelöscht."
    echo "Section $HEADER ist damit leer und wurde entfernt."
  fi
}

load_file "$PARAMS_FILE"

if [[ "$ACTION_LC" == "add" ]]; then
  do_add
else
  do_delete
fi
