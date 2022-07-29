#!/bin/bash
# This file contains the json_explorer function that uses jq, fzf and json_info to display all paths in a json file and let you view and select entries.
# This file can be sourced to add the json_explorer function to your environment.
# This file can also be executed to run the json_explorer function without adding it to your environment.
#
# File contents:
#   json_explorer  --> Select paths and output json with the selected entries.
#

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

json_explorer () {
    local do_not_run
    if [[ -z "$JSON_INFO_CMD" ]]; then
        printf 'unable to locate json_info script.\n' >&2
        return 1
    fi
    for req_cmd in 'jq' 'fzf' 'json_info' "$JSON_INFO_CMD"; do
        if ! command -v "$req_cmd" > /dev/null 2>&1; then
            do_not_run='yes'
            printf 'Missing required command: %s\n' "$req_cmd" >&2
            "$req_cmd"
        fi
    done
    if [[ -n "$do_not_run" ]]; then
        return 1
    fi
    local usage
    usage="$( cat << EOF
json_explorer - Select paths and output json with the selected entries.

Usage: json_explorer <filename>

    <filename> is the name of the json file to explore.

EOF
)"
    local filename
    if [[ "$#" -eq '2' ]] && [[ "$1" == '--' || "$1" == '-f' ]]; then
        filename="$2"
    elif [[ "$#" -eq '1' && "$1" != '-h' && "$1" != '--help' && "$1" != 'help' ]]; then
        filename="$1"
    else
        printf '%s\n' "$usage"
        return 0
    fi

    # Make sure the filename has a file.
    if [[ -d "$filename" ]]; then
        printf 'Input file [%s] is a directory.\n' "$filename" >&2
        return 1
    elif [[ ! -f "$filename" ]]; then
        printf 'Input file [%s] does not exist.\n' "$filename" >&2
        return 1
    fi

    local exit_code selections jpath result
    # Make sure the file contents are parseable json.
    jq '.' "$filename" > /dev/null
    exit_code=$?
    if [[ "$exit_code" -ne '0' ]]; then
        printf 'Invalid json.\n'
        return $exit_code
    fi

    # Prompt for paths to be selected
    selections="$( json_info --just-paths -r -f "$filename" | fzf --multi --preview="printf '%s\n' {} && '$JSON_INFO_CMD' -p {} -f '$filename' -d" --preview-window=':40%:wrap' --tac --cycle )"
    result='[]'
    while IFS= read -r jpath; do
        if [[ -n "$jpath" ]]; then
            result="$( jq -c --arg path "$jpath" --arg value "$( jq -c "$jpath" "$filename" )" ' . + [{"path":$path,"value":($value|fromjson)}]' <<< "$result" )"
        fi
    done <<< "$selections"
    if [[ "$result" != '[]' ]]; then
        jq '.' <<< "$result"
        return $?
    fi
    return 0
}

if [[ "$sourced" != 'YES' ]]; then
    where_i_am="$( cd "$( dirname "${BASH_SOURCE:-$0}" )"; pwd -P )"
    require_command () {
        local cmd cmd_fn
        cmd="$1"
        if ! command -v "$cmd" > /dev/null 2>&1; then
            cmd_fn="$where_i_am/$cmd.sh"
            if [[ -f "$cmd_fn" ]]; then
                source "$cmd_fn"
                if [[ "$?" -ne '0' ]] || ! command -v "$cmd" > /dev/null 2>&1; then
                    ( printf 'This script relies on the [%s] function.\n' "$cmd"
                      printf 'The file [%s] was found and sourced, but there was a problem loading the [%s] function.\n' "$cmd_fn" "$cmd" ) >&2
                    return 1
                fi
            else
                ( printf 'This script relies on the [%s] function.\n' "$cmd"
                  printf 'The file [%s] was looked for, but not found.\n' "$cmd_fn" ) >&2
                return 1
            fi
        fi
    }
    require_command 'json_info' || exit $?
    json_explorer "$@"
    exit $?
fi
unset sourced

return 0
