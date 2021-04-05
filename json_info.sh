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

Usage: json_info [-p <path>] [--show-path|--hide-path] {-f <filename>|-|-- <json>}

    -p <path> is the optional path to get information about.
        If provided multiple times, the information for each path will be output.
        If not provided, '.' is used.
    --show-path is an optional flag that causes the path to be part of the output.
        This is the default when there are more than one paths.
        If supplied with --hide-path, the last one is used.
    --hide-path is an optional flag that causes the path to NOT be part of the output.
        This is the default when there is only one path.
        If supplied with --show-path, the last one is used.

    Exactly one of the following must be provided to define the input json.
        -f <filename> will load the json from the provided filename
        - indicates that the json should be collected from stdin.
        -- <json> allows the json to be provided as part of the command.
            Everything after -- is treated as part of the json.

EOF
)"
    local input_count paths input_file input_stdin input show_path
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
        --show-path|--show-paths)
            show_path="yes"
            ;;
        --hide-path|--hide-paths)
            show_path="no"
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
            printf 'Unknown argument: [%s].\n' "$1" >&2
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
    if [[ -n "$input_stdin" ]]; then
        input="$( cat - )"
        input_stdin=''
    fi
    if [[ "${#paths[@]}" -eq '0' ]]; then
        paths+=('.')
    fi
    local max_width
    if command -v 'tput' > /dev/null 2>&1; then
        max_width="$( tput cols )"
        if [[ "$max_width" -lt '40' ]]; then
            max_width=0
        fi
    else
        max_width=0
    fi
    # Handle the default show path behavior and make sure that $show_path is either "yes" or empty.
    if [[ -z "$show_path" ]]; then
        if [[ "${#paths[@]}" -gt '1' ]]; then
            show_path='yes'
        fi
    elif [[ "$show_path" != 'yes' ]]; then
        show_path=''
    fi
    local min_trunc path exit_code jq_args jq_max_width jq_filter jq_output blank_path jq_exit_code
    # If there's more than one path, make sure none of them are so long that there wouldn't be much room left for a string.
    # If there is one, don't truncate anything.
    min_trunc=10
    if [[ "$max_width" -gt '0' && -n "$show_path" ]]; then
        for path in "${paths[@]}"; do
            # The 3 here comes from the " = " put between the path and its info.
            if [[ "$(( max_width - ${#path} - 3 ))" -lt "$min_trunc" ]]; then
                max_width=0
                break
            fi
        done
    fi

    exit_code=0
    for path in "${paths[@]}"; do
        jq_max_width="$max_width"
        if [[ -n "$show_path" ]]; then
            printf '%s = ' "$path"
            if [[ "$max_width" -gt '0' ]]; then
                # The 3 here comes from the " = " put between the path and its info.
                jq_max_width=$(( max_width - ${#path} - 3 ))
                if [[ "$jq_max_width" -lt "$min_trunc" ]]; then
                    jq_max_width=0
                fi
            fi
        fi
        jq_args=( -r --arg max_width_str "$jq_max_width" )
        printf -v jq_filter '($max_width_str|tonumber) as $max_width |
def null_info:    "null";
def boolean_info: "boolean: " + (.|tostring);
def number_info:  "number: " + (.|tostring);
def string_info:  "string: " + (.|@json| if $max_width == 0 or (.|length) <= ($max_width - 8) then . else (.[0:$max_width-11] + "...") end );
def array_info:   "array: " + (.|length|tostring) + " " + (if (.|length) == 1 then "entry" else "entries" end ) + ": " + ([.[]|type] | reduce .[] as $item ([]; if (.|contains([$item])|not) then . + [$item] else . end) | tostring | gsub("[\\\\]\\\\[\\"]"; "") | gsub(","; " "));
def object_info:  "object: " + (.|length|tostring) + " " + (if (.|length) == 1 then "key" else "keys" end ) + ": " + (.|keys|tostring);
%s | if (.|type) == "null" then (.|null_info)
   elif (.|type) == "boolean" then (.|boolean_info)
   elif (.|type) == "number" then (.|number_info)
   elif (.|type) == "string" then (.|string_info)
   elif (.|type) == "array" then (.|array_info)
   elif (.|type) == "object" then (.|object_info)
   else ""
end' "$path"
        if [[ -n "$input_file" ]]; then
            jq_output="$( jq ${jq_args[@]} "$jq_filter" "$input_file" 2> /dev/null )"
            jq_exit_code=$?
        elif [[ -n "$input" ]]; then
            jq_output="$( jq ${jq_args[@]} "$jq_filter" <<< "$input" 2> /dev/null )"
            jq_exit_code=$?
        fi
        if [[ "$jq_exit_code" -eq '0' ]]; then
            if [[ -n "$show_path" && "$( wc -l <<< "$jq_output" )" -gt '1' ]]; then
                blank_path="$( sed 's/./ /g' <<< "$path" )   "
                # The path has already been printed, just print the first line
                head -n 1 <<< "$jq_output"
                # Now print the rest of the lines with the blank path appended.
                tail -n +2 <<< "$jq_output" | sed "s/^/$blank_path/"
            else
                printf '%s\n' "$jq_output"
            fi
        else
            printf 'Invalid path\n'
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
