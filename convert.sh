#! /usr/bin/env bash
#
# convert.sh
# Version: Look at the first constant definitions below!
#
# Project Description:
#   en: Converts the Vivaldi CSV export of passwords (with header "name,url,username,password,note")
#       into a password list in the format: name + dot-padding + password.
#   de: Konvertiert den Vivaldi CSV-Export der Passwoerter (mit Kopfzeile "name,url,username,password,note")
#       in eine Passwortliste im Format: Name + Punkt-Auffuellung + Passwort.
#
# Details
#   en: Only fields $1 (name) and $4 (password) are used.
#       The sorting key is derived from the domain name:
#       The second-to-last subfield is considered when the name is dot-separated.
#       For example: "accounts.ard.de" yields "ard", "colibri.ai" yields "colibri".
# 
#   de: Dabei werden nur Feld $1 (Name) und Feld $4 (Passwort) genutzt.
#       Der Sortierschluessel wird aus dem Domainnamen abgeleitet:
#       Es wird das jeweils zweitletzte Subfeld betrachtet, wenn der Name durch Punkte getrennt ist.
#       Beispiel: "accounts.ard.de" liefert "ard", "colibri.ai" liefert "colibri".
#
# Usage:
# ./convert.sh
# 
# Dependencies:
#
# - gawk (GNU Awk)
# - find (aus findutils)
# - head (aus coreutils)
#
# History:   2025-06-15, 2025-06-20
#
# Copyright: 2025, Bernd Storck, https://www.facebook.com/BStLinux/
# License:   GNU General Public License 3.0
#

# > Value settings: < =======================================================

# > Constants: < ------------------------------------------------------------

readonly PROG_NAME="Passwort File Converter"
readonly ORIGINAL_SCRIPT_NAME="convert.sh"
readonly VERSION="1.2.0"
readonly CURRENT_SCRIPT_NAME="${0##*/}"

# > Defaults: < ------------------------------------------------------------

csv_input_file="${1:-Vivaldi-Passwörter.csv}"
output_file="vivaldi-passwords.txt"


# > Functions: < ============================================================

load_config() {
  local config_file="$1"

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *.csv) csv_input_file="$line" ;;
      *.txt|*.list) output_file="$line" ;;
    esac
  done < "$config_file"
}

# Searching for configuration file:
# Searching for configuration file:
config_file=$(./find_config.sh getpass getpass F getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:.")
if [ $? -ne 0 ] || [ -z "$config_file" ]; then
    echo "FEHLER: Keine Konfigurationsdatei gefunden!" >&2
    exit 1
else
    load_config "$config_file"
fi

# Fallback: Falls CSV nicht existiert, suche im aktuellen Verzeichnis
if [ ! -f "$csv_input_file" ]; then
  for current_file in $(find . -maxdepth 1 -iname "*.csv"); do
    first_line="$(head -n 1 "$current_file")"
    if [ "$first_line" = 'name,url,username,password,note' ]; then
      csv_input_file="$current_file"
      break
    fi
  done
fi

if [ ! -f "$csv_input_file" ]; then
  echo "CSV input file not found!"
  exit 1
fi

# Hier wird AWK verwendet:
#  - Es wird die Kopfzeile uebersprungen (NR==1).
#  - In jedem Datensatz werden:
#     * Feld $1 (Name) und Feld $4 (Passwort) eingelesen und von umschliessenden Anfuehrungszeichen bereinigt.
#     * Als Index wird "i = NR-1" verwendet.
#     * Der Sortierschluessel wird ermittelt, in dem das Feld $1 anhand des Punktes in Subfelder zerlegt wird.
#       Wird mindestens ein Punkt gefunden, so wird das zweitletzte Subfeld (parts[n-1]) als Schluessel genutzt
#       (beispielhaft: aus "accounts.ard.de" wird "ard", aus "colibri.ai" wird "colibri").
#     * Die Arrays names[i], pwds[i] und keys[i] werden gefuellt.
#
# Im END-Block wird dann mit asorti() ueber die keys der Index array sorted_indices erzeugt,
# mit dem die Datensaetze in sortierter Reihenfolge ausgegeben werden.
#
# Zusaetzlich werden mit der Laenge des Namens ein "dot-padding" erzeugt, sodass der Passwortteil
# immer in Spalte 33 beginnt (kannst du natuerlich anpassen).

awk -F, 'NR==1 { next }  # Kopfzeile ueberspringen
{
  # Felder $1 und $4 extrahieren und von Anfuehrungszeichen befreien
  name = $1; pwd = $4;
  gsub(/^"|"$/, "", name);
  gsub(/^"|"$/, "", pwd);

  # Speichern in Arrays – Index = (NR-1) wegen Kopfzeilenübersprung
  i = NR - 1;
  names[i] = name;
  pwds[i]  = pwd;

  # zum Sortieren die Domain ermitteln:
  n = split(name, parts, ".");  # Zerlegt 'name' anhand des Punktes.
  postfix = sprintf("%05d", i)
  if (n > 1) {
    key = tolower(parts[n-1]);  # Zweitletztes Subfeld als Schluessel
  } else {
    key = tolower(name);        # Falls kein Punkt vorhanden ist
  }
  # AWK-Äquivalent zu: 'key="$(grep -Eo '[-_[:alnum:]]{2,}$' <<< "$key")"'
  if (match(key, /[-_[:alnum:]]{2,}$/)) {
    key = substr(key, RSTART, RLENGTH);
  }
  keys[i] = key"-"postfix;
  # print keys[i]

  count = i;  # Anzahl der eingelesenen Zeilen
}

# Benutzerdefinierte Vergleichsfunktion fuer case-insensitive Sortierung
function ci_sort(i1, v1, i2, v2) {
  return (v1 < v2) ? -1 : (v1 > v2);
}

function dot_padding(txt, len_name, dots_count, dots) {
  # Berechne das Dot-Padding (Spalte 33):
  len_name = length(txt);
  dots_count = 33 - len_name;
  if (dots_count < 0) dots_count = 0;
  dots = sprintf("%" dots_count "s", "");
  gsub(/ /, ".", dots);  # Ersetzt alle Leerzeichen durch Punkte
  return dots
}

END {

  dots = dot_padding("NAME")
  printf "%s %s %s\n\n", "NAME", dots, "PASSWORD";

  # Sortiere die Indizes basierend auf den Werten in keys (case-insensitive)
  asorti(keys, sorted_indices, "ci_sort");

  for (i = 1; i <= count; i++) {
    idx = sorted_indices[i];

    # Berechne das Dot-Padding (Spalte 33):
    dots = dot_padding(names[idx])

    # Ausgabe im Format: name <dot-padding> password
    printf "%s %s %s\n", names[idx], dots, pwds[idx];
  }
}' "$csv_input_file" > "$output_file"

echo "Converted CSV file '$csv_input_file' to password list '$output_file'." > /dev/stderr
