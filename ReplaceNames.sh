#!/usr/bin/env bash
# Victor-ray, S <12261439+ZendaiOwl@users.noreply.github.com>

# A log that uses log levels for logging different outputs
# Log levels
# -2: Debug
# -1: Info
#  0: Success
#  1: Warning
#  2: Error
function log {
  if [[ "$#" -gt 0 ]]
  then
    local -r LOGLEVEL="$1" TEXT="${*:2}" Z='\e[0m'
    if [[ "$LOGLEVEL" =~ [(-2)-2] ]]
    then
      case "$LOGLEVEL" in
        -2)
           local -r CYAN='\e[1;36m'
           printf "${CYAN}DEBUG${Z} %s\n" "$TEXT"
           ;;
        -1)
           local -r BLUE='\e[1;34m'
           printf "${BLUE}INFO${Z} %s\n" "$TEXT"
           ;;
         0)
           local -r GREEN='\e[1;32m'
           printf "${GREEN}SUCCESS${Z} %s\n" "$TEXT"
           ;;
         1)
           local -r YELLOW='\e[1;33m'
           printf "${YELLOW}WARNING${Z} %s\n" "$TEXT"
           ;;
         2)
           local -r RED='\e[1;31m'
           printf "${RED}ERROR${Z} %s\n" "$TEXT"
           ;;
      esac
    else
      log 2 "Invalid log level: [Debug: -2|Info: -1|Success: 0|Warning: 1|Error: 2]"
    fi
  fi
}

# Checks if a command exists on the system
# Return status codes
# 0: Command exists on the system
# 1: Command is unavailable on the system
# 2: Missing command argument to check
function hasCMD {
  if [[ "$#" -eq 1 ]]
  then
    local -r CHECK="$1"
    if command -v "$CHECK" &>/dev/null
    then
      return 0
    else
      return 1
    fi
  else
    return 2
  fi
}

# Checks if a given path is a regular file
# 0: Is a file
# 1: Not a file
# 2: Invalid number of arguments
function isFile {
  [[ "$#" -ne 1 ]] && return 2
  [[ -f "$1" ]]
}

# Search for files with pattern(s) recursively
# Return codes
# 0: Success
# 1: Missing argument: String pattern to locate
# 2: Missing command: grep
function getFilesWithText {
  if hasCMD grep &>/dev/null
  then
    if [[ "$#" -gt 0 ]]; then
      local -r PATTERN="$*" ARGS=(--recursive --files-with-matches --exclude-dir=".*")
      grep "${ARGS[@]}" "$PATTERN" 2>/dev/null
      return 0
    else
      return 1
    fi
  else
    log 2 "Missing command: grep"
    return 2
  fi
}

# Replaces given text pattern with a new one in all files recursively from current working directory
# Return codes
# 0: Success
# 1: Missing arguments: String, String
# 2: Missing command: sed
function replaceTextInAllFiles {
  if ! hasCMD sed &>/dev/null; then
    return 2
  elif [[ "$#" -ne 2 ]]; then
    return 1
  else
    local -r FINDTEXT="$1" NEWTEXT="$2"
    for F in $(getFilesWithText "$FINDTEXT"); do
      sed -i "s|${FINDTEXT}|${NEWTEXT}|g" "$F"
    done
    return 0
  fi
}

if isFile ReplaceNames.txt; then
  IN=()
  CURRENT='ReplaceNames.txt'
  SECOND='RevertNames.txt'
  if isFile "$SECOND"; then
    mv "$SECOND" "../$SECOND"
  fi
  BACKUP='../.backup'
  cat "$CURRENT" > "$BACKUP"
  for LINE in $(cat "$BACKUP"); do
    IN+=("$(printf '%s\n' "$LINE")")
  done
  LENGTH="${#IN[@]}"
  for (( i = 0; i < "$LENGTH"; i+=2 )); do
    echo "Replacing: ${IN[$i]} | With: ${IN[$(($i + 1))]}"
    replaceTextInAllFiles "${IN[$i]}" "${IN[$(($i + 1))]}"
  done
  mv "$BACKUP" "$CURRENT"
  if isFile "../$SECOND"; then
    mv "../$SECOND" "$SECOND"
  fi
  unset IN LENGTH CURRENT SECOND BACKUP
else
  exit 1
fi
