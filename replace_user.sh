#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Uso: $0 <novo_login>"
	exit 1
fi

OLD_REGEX='mviana(-v)?'
NEW="$1"
SCRIPT_NAME="$(basename "$0")"

grep -rIlZ \
	--exclude-dir=".git" \
	--exclude="$SCRIPT_NAME" \
	-E "$OLD_REGEX" . |
while IFS= read -r -d '' file; do
	sed -E -i "s|$OLD_REGEX|$NEW|g" "$file"
	echo "Alterado: $file"
done
