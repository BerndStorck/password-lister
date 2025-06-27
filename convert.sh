#!/usr/bin/env bash
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
# History:   2025-06-15, 2025-06-20, 2025-06-23, 2025-06-27
#
# Author:    Bernd Storck, Berlin
#
# Copyright: 2025, Bernd Storck, https://www.facebook.com/BStLinux/
# License:   GNU General Public License 3.0
#

# set -x  # -euo pipefail

# > Value settings: < =======================================================

# > Constants: < ------------------------------------------------------------

readonly PROG_NAME="Passwort File Converter"
readonly ORIGINAL_SCRIPT_NAME="convert.sh"
readonly VERSION="2.0.0"
readonly CURRENT_SCRIPT_NAME="${0##*/}"

readonly VIVALDI_FIRST_LINE='name,url,username,password,note'
readonly FIREFOX_FIRST_LINE='"url","username","password","httpRealm","formActionOrigin","guid","timeCreated","timeLastUsed","timePasswordChanged"'

# > Defaults: < ------------------------------------------------------------

input_format="chromium"
csv_input_file="${1:-Vivaldi-Passwörter.csv}"
output_file="vivaldi-passwords.txt"
passwords_display_start_column=35
csv_input_file_found=0

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

normalize_header() {
    echo "$1" | tr -d '\r\n"' | tr -d ' ' | tr '[:upper:]' '[:lower:]'
}

get_prefix() {
  local file="$1" base first_word

  if [ -z "${1:-}" ]; then
    printf 'ERROR: no filename provided to get_prefix\n' >&2
    return 1
  fi

  base="${file##*/}"  # Removes path.
  # Nimmt alles bis zum ersten Leerzeichen oder Bindestrich:
  first_word="${base%%[- _]*}"   # Extracts everything up to the first space or hyphen.

  if (( BASH_VERSINFO[0] >= 4 )); then
    first_word="${first_word,,}"  # To lower case.
  else
    first_word="$(printf '%s' "$first_word" | tr '[:upper:]' '[:lower:]')"
  fi

  printf '%s\n' "$first_word"
}


# > main < ============================================================

# Searching for configuration file:
config_file=$(./find_config.sh getpass getpass F getpass.conf "$PWD:$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc")
if [ $? -ne 0 ] || [ -z "$config_file" ]; then
    echo "FEHLER: Keine Konfigurationsdatei gefunden!" >&2
    exit 1
else
    :
    # load_config "$config_file"
fi

vivaldi_first_line_normalized="$(normalize_header "$VIVALDI_FIRST_LINE")"
firefox_first_line_normalized="$(normalize_header "$FIREFOX_FIRST_LINE")"

if [ -f "$csv_input_file" ]; then  # Assume source browser:
  first_line="$(head -n 1 "$csv_input_file")"
  first_line_normalized=$(normalize_header "$first_line")
  case "$first_line_normalized" in 
    "$vivaldi_first_line_normalized")
       input_format='chromium'
       prefix="$(get_prefix "$csv_input_file")"
       output_file="$prefix-passwords.txt"
       csv_input_file_found=1
       ;;
    "$firefox_first_line_normalized")
       input_format='firefox'
       prefix="$(get_prefix "$csv_input_file")"
       output_file="$prefix-passwords.txt"
       csv_input_file_found=1
       ;;
  esac
else  # Fallback: CSV im aktuellen Verzeichnis finden:
   while IFS= read -r -d '' current_file; do
     first_line="$(head -n1 "$current_file")"
     first_line_normalized=$(normalize_header "$first_line")
     case "$first_line_normalized" in
       "$vivaldi_first_line_normalized")
         input_format='chromium'
         csv_input_file="$current_file"
         csv_input_file_found=1
         break
         ;;
       "$firefox_first_line_normalized")
         input_format='firefox'
         csv_input_file="$current_file"
         csv_input_file_found=1
         break
         ;;
     esac
   done < <(find . -maxdepth 1 -iname '*.csv' -print0)
fi

if [ "$csv_input_file_found" -eq 0 ]; then
  echo "CSV input file not found!" >&2
# echo "Kein gültiges CSV-Format im aktuellen Verzeichnis gefunden." >&2
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
# in der Ausgabe standardmaessig immer in Spalte 35 beginnt ('passwords_display_start_column').

awk -F, -v input_format="$input_format" -v password_start="$passwords_display_start_column" 'NR==1 { next }  # Kopfzeile ueberspringen
{

  if ( input_format == "chromium" ) {
    name = $1; pwd = $4;
  } else if ( input_format == "firefox" ) {
    name = $1; pwd = $3;
  }

  # Felder $1 und $4 extrahieren und von Anfuehrungszeichen befreien
  gsub(/^"|"$/, "", name);
  gsub(/^"|"$/, "", pwd);

  gsub(/^https:\/\/|^http:\/\//, "", name);

  # Speichern in Arrays:
  i = NR - 1;  # Index = (NR-1) weil die Kopfzeile uebersprungen wurde.
  names[i] = name;
  pwds[i]  = pwd;

  key = get_key(name);  # Ermittelt zum Sortieren die Domain. Sie wird zum Sortierschluessel.

  postfix = sprintf("%05d", i);
  keys[i] = key"-"postfix;  # key ist das Array der Sortierschluessel, dies sind diesfalls die Domainnamen.
  # print keys[i]

  count = i;  # Anzahl der eingelesenen Zeilen
}

function get_key (name) {

  # split() ist eine Funktion, die das String-Argument (name) anhand
  # des Trennzeichens (".") in einen Array (parts) aufteilt.
  #
  # Beim Aufruf der Funktion split wird das Array parts bei jedem
  # Aufruf neu initialisiert/ueberschrieben.

  total_number_of_parts = split(name, parts, ".");  # Zerlegt 'name' anhand des Punktes.
  # 'parts' ist das Array, das nun alle Felder enthaelt.

  if (total_number_of_parts > 1) {
    key = tolower(parts[total_number_of_parts - 1]);  # Zweitletztes Subfeld als Schluessel
  } else {
    key = tolower(name);        # Falls kein Punkt vorhanden ist
  }
  # AWK-Aequivalent zu: 'key="$(grep -Eo '[-_[:alnum:]]{2,}$' <<< "$key")"'
  if (match(key, /[-_[:alnum:]]{2,}$/)) {
    key = substr(key, RSTART, RLENGTH);
  }

  return key
}

# Benutzerdefinierte Vergleichsfunktion fuer case-insensitive Sortierung
function ci_sort(i1, v1, i2, v2) {
  return (v1 < v2) ? -1 : (v1 > v2);
}

function dot_padding(txt, len_name, dots_count, dots) {
  # Berechne das Dot-Padding:
  len_name = length(txt);
  dots_count = (password_start - 2) - len_name;  # 1 space before and after the dots)
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
