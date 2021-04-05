#!/bin/bash
# This file contains the json_info function that uses jq to output information about a json structure.
# This file can be sourced to add the json_info function to your environment.
# This file can also be executed to run the json_info function without adding it to your environment.
#
# File contents:
#   json_info  --> Outputs information about the provided json structure.
#

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

json_info () {
    if ! command -v "jq" > /dev/null 2>&1; then
        printf 'Missing required command: jq\n' >&2
        jq
        return $?
    fi
    local usage
    usage="$( cat << EOF
json_info - Outputs information about a json structure.

Usage: json_info [-p <path>] {-f <filename>|-|-- <json>}

    -p <path> is the optional path to get information about.
        If provided multiple times, the information for each path will be output.
        If not provided, '.' is used.

    Exactly one of the following must be provided to define the input json.
        -f <filename> will load the json from the provided filename
        - indicates that the json should be collected from stdin.
        -- <json> allows the json to be provided as part of the command.
            Everything after -- is treated as part of the json.

EOF
)"
    local paths input_file input_stdin input input_count
    input_count=0
    paths=()
    while [[ "$#" -gt '0' ]]; do
        case "$1" in
        -p|--path)
            if [[ -z "$2" ]]; then
                printf 'No path provided after %s\n' "$1" >&2
                return 1
            fi
            paths+=( "$2" )
            shift
            ;;
        -f|--file)
            if [[ -z "$2" ]]; then
                printf 'No input file provided after %s\n' "$1" >&2
                return 1
            fi
            input_file="$2"
            shift
            input_count=$(( input_count + 1 ))
            ;;
        -)
            input_stdin='yes'
            input_count=$(( input_count + 1 ))
            ;;
        --)
            shift
            input="$*"
            if [[ "$input" =~ ^[[:space:]]*$ ]]; then
                printf 'No input provided after --\n' >&2
                return 1
            fi
            set --
            input_count=$(( input_count + 1 ))
            ;;
        *)
            printf 'Unknown option: [%s].\n' "$1" >&2
            return 1
            ;;
        esac
        shift 2> /dev/null
    done
    if [[ "$input_count" -eq '0' ]]; then
        printf 'No input\n' >&2
        return 1
    elif [[ "$input_count" -ge '2' ]]; then
        printf 'Only one input can be defined.\n' >&2
        return 1
    fi
    if [[ -n "$input_file" ]]; then
        if [[ -d "$input_file" ]]; then
            printf 'Input file [%s] is a directory.' "$input_file" >&2
            return 1
        elif [[ ! -f "$input_file" ]]; then
            printf 'Input file [%s] does not exist.' "$input_file" >&2
            return 1
        fi
    fi
    if [[ "${#paths[@]}" -eq '0' ]]; then
        paths+=('.')
    fi
    if [[ -n "$input_stdin" ]]; then
        input="$( cat - )"
        input_stdin=''
    fi
    local max_width
    if command -v 'tput' > /dev/null 2>&1; then
        max_width="$( tput cols )"
    else
        max_width=0
    fi
    local path exit_code jq_args jq_max_width jq_filter jq_exit_code
    exit_code=0
    for path in "${paths[@]}"; do
        jq_max_width="$max_width"
        if [[ "${#paths[@]}" -gt '1' ]]; then
            printf '%s = ' "$path"
            jq_max_width=$(( max_width - ${#path} - 3 ))
        fi
        jq_args=( -r --arg max_width_str "$jq_max_width" )
        printf -v jq_filter '($max_width_str|tonumber) as $max_width |
def null_info: "null";
def boolean_info: "boolean: " + (.|tostring);
def number_info: "number: " + (.|tostring);
def string_info: "string: " + (.|@json| if $max_width == 0 or (.|length) <= ($max_width - 8) then . else (.[0:$max_width-11] + "...") end );
def array_info: "array: " + (.|length|tostring) + " " + (if (.|length) == 1 then "entry" else "entries" end ) + ": unfinished";
def object_info: "object: " + (.|length|tostring) + " " + (if (.|length) == 1 then "key" else "keys" end ) + ": " + (.|keys|tostring);
%s | if (.|type) == "null" then (.|null_info)
   elif (.|type) == "boolean" then (.|boolean_info)
   elif (.|type) == "number" then (.|number_info)
   elif (.|type) == "string" then (.|string_info)
   elif (.|type) == "array" then (.|array_info)
   elif (.|type) == "object" then (.|object_info)
   else ""
end' "$path"
        if [[ -n "$input_file" ]]; then
            jq ${jq_args[@]} "$jq_filter" "$input_file"
            jq_exit_code=$?
        elif [[ -n "$input" ]]; then
            jq ${jq_args[@]} "$jq_filter" <<< "$input"
            jq_exit_code=$?
        fi
        if [[ "$jq_exit_code" -ne '0' ]]; then
            exit_code=$jq_exit_code
        fi
    done
    return $exit_code
}

if [[ "$sourced" != 'YES' ]]; then
    json_info "$@"
    exit $?
fi
unset sourced

return 0
