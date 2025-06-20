#!/usr/bin/env bash
#
# find_config.sh
# Version: Look at the first constant definitions below!
#
# Project Description:
#   en: Searches for a configuration file based on a given colon-separated path list containing a placeholder "callerCfg".
#   de: Sucht anhand einer übergebenen, durch Doppelpunkte untergliederten Pfadliste mit einem Platzhalter "callerCfg" nach einer Konfigurationsdatei.
# 
# Usage: 
#
# Aufrufparameter:
#   $1: Familienname (z. B. "getpass")
#   $2: Individualname (z. B. "getpass", "lspass" oder "convert")
#   $3: NameFlag – gibt an, ob der Familienname (Wert "F")
#       oder der Individualname (Wert "I") für die Pfadsubstitution genutzt werden soll.
#   $4: Name der Konfigurationsdatei (z. B. "getpass.conf")
#   $5: Colon-separierte Liste von Basisverzeichnissen, z. B.
#       "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:."
#
# Beispielaufruf:
#   config_file=$(./find_config.sh getpass getpass F getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:.")
#   if [ -z "$config_file" ]; then
#     echo "Configuration file not found!" >&2
#     exit 1
#   fi
#
# History:   2025-06-20
#
# Author:    Bernd Storck
# Contact:   https://www.facebook.com/BStLinux/
#
# Copyright: 2025, Bernd Storck
# License:   GNU General Public License 3.0
#

# > Value settings: < =======================================================

# > Constants: < ------------------------------------------------------------

readonly ORIGIN_SCRIPT_NAME="find_config.sh"  # original script name
readonly VERSION="1.0.0"
readonly CURRENT_SCRIPT_NAME="${0##*/}"  # Saves the basename of the script file.


# > Functions: < ============================================================

usage () {
if [ "$UILANG" = "Deutsch" ]; then

  cat << _EOT_

 $ORIGIN_SCRIPT_NAME  (Version $VERSION)

 Sucht anhand einer übergebenen, durch Doppelpunkte untergliederten Pfadliste mit einem Platzhalter "callerCfg" nach einer Konfigurationsdatei.

 AUFRUFPARAMETER / OPTIONEN
    --hilf         Diese Hilfe anzeigen
    --version|-V   Versionsinfo anzeigen

 AUFRUFBEISPIELE

  $CURRENT_SCRIPT_NAME getpass getpass F getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:."
  $CURRENT_SCRIPT_NAME getpass convert I getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:."

  Falls der dritte Parameter "F" (Familienname) ist, wird "callerCfg" durch den zweiten Parameter ersetzt, z.B. "getpass".
  Falls der dritte Parameter "I" (Individueller Name) ist, wird "callerCfg" durch den zweiten Parameter ersetzt, z.B. "convert".

 Programmiert von Bernd Storck, facebook.com/BStLinux/
 (GNU/General Public License version 2.0)

_EOT_

else  # English help:

  cat << _EOT_

 $ORIGIN_SCRIPT_NAME (Version $VERSION)

 Searches for a configuration file based on a given colon-separated path list containing a placeholder "callerCfg".

 COMMAND LINE PARAMETERS / OPTIONS
    --help         Show this help message.
    --version|-V   Show version information.

 USAGE EXAMPLES

  $CURRENT_SCRIPT_NAME getpass getpass F getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:."
  $CURRENT_SCRIPT_NAME getpass convert I getpass.conf "$HOME/callerCfg:$HOME/.config/callerCfg:$HOME/.config:$HOME:/etc/callerCfg:/etc:."

  If the third parameter is "F" (family name), "callerCfg" will be replaced by the second parameter, e.g., "getpass".
  If the third parameter is "I" (individual name), "callerCfg" will be replaced by the second parameter, e.g., "convert".

 Programmed by Bernd Storck, facebook.com/BStLinux/
 (GNU/General Public License version 2.0)

_EOT_

fi
}


# > main < ============================================================

# > Call parameter Analysis: < ----------------------------------------


for current_option in "$@"; do
  case "$current_option" in
     --hilf|--hilfe|--Hilfe)  # Calls German help regardless of system settings for language.
         UILANG="DEUTSCH"
         usage
         exit 0
         ;;
     --help|-h)
         if [ "${LANG::2}" = 'de' ]; then
             UILANG="Deutsch"
         fi
         usage
         exit 0
         ;;
     --version|-V|-\#)   # For possible bug reports.
         answer=
         if [ "$1" = "--version" ] || [ "$1" = "-V" ]; then
             answer="$SCRIPT_NAME "
         fi
         answer="${answer}$VERSION"
         if [ "$1" != '-#' ] && [ "$CURRENT_SCRIPT_NAME" != "$SCRIPT_NAME" ]; then
           answer="${answer} ($CURRENT_NAME_PRAEFIX $CURRENT_SCRIPT_NAME)"
         fi
         echo "$answer"
         exit 0
         ;;
  esac
done

# Überprüfen, ob alle erforderlichen Parameter übergeben wurden
if [ "$#" -lt 5 ]; then
    echo "Usage: $0 <family_name> <individual_name> <flag: F|I> <config_filename> <path_list>" >&2
    exit 1
fi

FAMILY="$1"
INDIVIDUAL="$2"
FLAG="$3"
CFG_NAME="$4"
PATH_LIST="$5"

# Bestimme den Ersatztext anhand des Flags
if [ "$FLAG" = "F" ]; then
    SUBST="$FAMILY"
elif [ "$FLAG" = "I" ]; then
    SUBST="$INDIVIDUAL"
else
    echo "Invalid flag value: must be 'F' (family) or 'I' (individual)" >&2
    exit 1
fi

# Zerlege die PATH_LIST anhand des Doppelpunkt-Trennzeichens
IFS=':' read -ra DIRS <<< "$PATH_LIST"

for dir in "${DIRS[@]}"; do
    # Ersetze Vorkommen des Platzhalters "callerCfg" durch den gewünschten Wert.
    dir="${dir//callerCfg/$SUBST}"

    # Entferne eventuell überflüssige Schrägstriche am Ende.
    dir="${dir%/}"

    # Zusammenbauen des vollständigen Pfades zur Konfigurationsdatei.
    config_file="${dir}/${CFG_NAME}"

    # Prüfen, ob die Datei existiert.
    if [ -f "$config_file" ]; then
        echo "$config_file"
        exit 0
    fi
done

# Falls keine Datei gefunden wurde, mit Fehlercode beenden.
exit 1
