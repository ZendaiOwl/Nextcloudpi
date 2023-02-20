#!/usr/bin/env bash

function Clean
{
    #unset GREP_PATTERN
    unset ONE TWO FILE
}

# Replaces given text pattern with a new one in all files recursively from current working directory
# Return codes
# 0: Success
# 1: Missing arguments: String, String
# 2: Missing command: sed
function replace_all_text {
    for F in $(get_files_with_text "$1")
    do sed -i "s|$1|$2|g" "$F"
    done; return 0
}

# search for files with pattern(s) recursively
# Return codes
# 0: Success
# 1: Missing argument: String
# 2: Missing command: grep
function get_files_with_text {
    if [[ "$#" -gt 0 ]]
    then declare -r ARGS=(--recursive --files-with-matches --exclude-dir=".*")
         grep "${ARGS[@]}" "$*" 2>/dev/null; return 0
    else log 2 "Requires: [Pattern(s) to locate]"; return 1
    fi
}

#GREP_PATTERN=('function ' ' () {' ' () ')

trap 'Clean' EXIT SIGHUP SIGILL SIGINT SIGABRT

# Names using function() keyword
#grep "${GREP_PATTERN[0]}" lib.sh

# Function name declarations using () {
#grep "${GREP_PATTERN[1]}" lib.sh

# Function name declarations using () 
#grep "${GREP_PATTERN[2]}" lib.sh

# Only the names
#awk '{print $2}' <(grep "${GREP_PATTERN[0]}" lib.sh)

# Add () to function() names
#awk '{print $2 " ()"}' <(grep "${GREP_PATTERN[0]}" lib.sh)

# Print with function() in the name
#awk '{print $1,$2 " ()"}' <(grep "${GREP_PATTERN[0]}" lib.sh)

FILE='names.txt'
HIDDEN_FILE='./.names.txt'

mapfile -t ONE < <(awk '{print $1}' "$FILE")

mapfile -t TWO < <(awk '{print $2}' "$FILE")

mv "$FILE" "$HIDDEN_FILE"

if [[ "${#ONE[@]}" -eq "${#TWO[@]}" ]]
then for (( i = 0; i < "${#ONE[@]}"; i++ ))
     do printf '%s %s\n' "Replacing: ${ONE[$i]} |" "With: ${TWO[$i]}"
        replace_all_text "${ONE[$i]}" "${TWO[$i]}"
     done
fi

mv "$HIDDEN_FILE" "$FILE"
