#!/bin/bash

if [ "$#" -ne 1 ]; then
	echo "Uso: $0 <novo_login>"
	exit 1
fi

OLD="mviana-v"
NEW="$1"

grep -rlZ --exclude-dir=".git" -- "$OLD" . |
while IFS= read -r -d '' file; do
	sed -i "s|$OLD|$NEW|g" "$file"
	echo "Alterado: $file"
done
