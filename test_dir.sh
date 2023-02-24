#!/usr/bin/env bash
# Victor-ray, S <12261439+ZendaiOwl@users.noreply.github.com>

[[ "$#" -gt 2 ]] && { exit 1; }
if [[ "$#" -ge 1 ]]; then
    mapfile -t DIRS < <(ls -l -d "$1"/*/*/* | awk '{print $9}')
else
    mapfile -t DIRS < <(ls -l -d */*/*/* | awk '{print $9}')
fi

DIR_TXT_FILE="${2:-directories.txt}"

[[ -f "$DIR_TXT_FILE" ]] && {
    rm "$DIR_TXT_FILE"
}
touch "$DIR_TXT_FILE"

for D in "${DIRS[@]}"; do
    if [[ -e "$D" ]]; then
        printf '%s\n' "Pass: $D"
    else
        printf '%s\n' "Fail: $D"
    fi
    printf '%s\n' "$D" >> "$DIR_TXT_FILE"
done

unset DIRS DIR_TXT_FILE

# 124 directories
