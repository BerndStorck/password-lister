#!/usr/bin/env bash

password_file="${1:-"$HOME/.local/share/passwords/vivaldi-passwords.txt"}"

grep -h --color=always -E "^.{5,} " "$password_file" | less -r
