#!/usr/bin/env bash
#
# getpass.sh
# Version: Look at the first constant definitions below!
#
# Project Description:
#   en: Extracts passwords for a domain from a password list.
#   de: Extrahiert Passwörter zu einer Domain aus einer Passwortliste.
#
# Usage:
# ./getpass domain
#
# Dependencies:
# - lspass.sh
# - sed
# - grep
# - less
# - awk
#
# History:   2025-04-21, 2025-06-14, 2025-06-15, 2025-06-20
#
# Copyright: 2025, Bernd Storck
# License:   GNU General Public License 3.0
#

# set -x

# > Value settings: < =======================================================

# > Constants: < ------------------------------------------------------------

readonly PROG_NAME="Passwort Lister"
readonly ORIGINAL_SCRIPT_NAME="getpass.sh"
readonly VERSION="1.2.0"
readonly CURRENT_SCRIPT_NAME="${0##*/}"

password_file="$HOME/.local/share/passwords/vivaldi-passwords.txt"


# > Functions: < ============================================================

normalize_option () {
# For error tolerance, the script accepts '-option' for '--option',
# regardless of the string that is substituted for 'option', as long as
# it is longer than one character.
#
# In addition, the option name is translated to lowercase.
#
# Overall, this causes '-examples' to be translated to '--examples',
# for example.

  if grep -Evq '^[[:alnum:]]' <<< "$1" 2>&1 > /dev/null; then
    # Converts leading '-' to '--':
    sed -E 's:^-{1}([a-z]{2,}):--\1:' <<< "$1" | tr '[:upper:]' '[:lower:]'
  else
    echo "$1"
  fi
}

usage () {
if [ "${LANG::2}" == "de" ]; then

  cat << _EOT_

 $PROG_NAME  (Version $VERSION)

 Extrahiert Passwörter für die angegebene Domain aus der Passwortdatei.

 AUFRUFPARAMETER / OPTIONEN
    --hilf         Diese Hilfe anzeigen
    --version|-V   Versionsinfo anzeigen

 VERWENDUNG: $CURRENT_SCRIPT_NAME <domain>

 AUFRUFBEISPIELE

  $CURRENT_SCRIPT_NAME discord
  $CURRENT_SCRIPT_NAME discord.com

 Programmiert von Bernd Storck, facebook.com/BStLinux/
 (GNU/General Public License version 2.0)

_EOT_

else  # English help:

  cat << _EOT_

 $PROG_NAME (Version $VERSION)

 Extracts passwords for a domain from a password list.

 COMMAND LINE PARAMETERS / OPTIONS
    --help         Show this help message.
    --version|-V   Show version information.

 USAGE: $CURRENT_SCRIPT_NAME <domain>

 USAGE EXAMPLES

  $CURRENT_SCRIPT_NAME discord
  $CURRENT_SCRIPT_NAME discord.com

 Programmed by Bernd Storck, facebook.com/BStLinux/
 (GNU/General Public License version 2.0)

_EOT_

fi
}


load_config() {
  local config_file="$1"

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      *.txt|*.list) password_file="$line" ;;
    esac
  done < "$config_file"
}


# > main < ============================================================

# Searching for configuration file:
config_file=$(./find_config.sh getpass getpass F getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:.")
if [ $? -ne 0 ] || [ -z "$config_file" ]; then
    echo "FEHLER: Keine Konfigurationsdatei gefunden!" >&2
    exit 1
else
    load_config "$config_file"
fi

#file_found=false
#for config_path in "$HOME/getpass" "$HOME/.config/getpass" "$HOME/.config" "$HOME" "/etc/getpass" "/etc" "."; do
#  configuration_file="${config_path}/getpass.conf"
#  # echo "[DEBUG] configuration_file: \"$configuration_file\""
#  if [ -f "$configuration_file" ]; then
#    load_config "$configuration_file"
#    file_found=true
#    break
#  fi
#done

# > Call parameter Analysis: < ----------------------------------------

# Catch calls with long options:
if [ "$#" -gt 0 ]; then
  for i in "$@"; do
    option=$(normalize_option "$i")
    case "$option" in
        --help|--hilf)
          usage
          exit 0
          ;;
        --version)
          printf "%s (Version %s)%s\n" "$ORIGINAL_SCRIPT_NAME" "$VERSION" "$current_file_name_reference"
          exit 0
          ;;
    esac
  done
fi


# Catch single letter options:
while getopts "p:hV\#" opt; do
  case $opt in
    p)
      password_file="$OPTARG"  # Passwortdatei
      ;;
    h) usage; exit 0 ;;  # Hilfe anzeigen
    \#) echo "$VERSION"; exit 0 ;;  # Versionsnummer anzeigen
    V)
       printf "%s (Version %s)\n" "$ORIGINAL_SCRIPT_NAME" "$VERSION"
       exit 0
       ;;
    \?) echo "WARNUNG: Ungültige Option: -$OPTARG" > /dev/stderr ;;
  esac
done
shift $((OPTIND-1))

echo "Passworddatei: \"$password_file\""
sleep 1

if [ ! -f "$password_file" ]; then
  echo "Datei \"$password_file\" wurde nicht gefunden."
  exit 1
fi

if [ $# -eq 0 ]; then
  if [ -x "./lspass.sh" ]; then
    ./lspass.sh "$password_file"
  else
    lspass.sh "$password_file"
  fi
  exit 1
fi

if [[ "$1" == *.* ]]; then
  pattern="$1"
else
  # Der regulaere Ausdruck prueft, ob das Muster "domain." gefolgt von einer TLD in der Zeile vorhanden ist.
  pattern="${1}(.)[a-z]{2,5}"
fi

awk -v pattern="$pattern" '
{
  if ($1 ~ pattern) {
    print $0
  }
}' "$password_file"
