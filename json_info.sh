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
    local min_trunc path_delim usage
    min_trunc=20
    path_delim=' = '
    usage="$( cat << EOF
json_info - Outputs information about a json structure.

Usage: json_info [-p <path>] [-r] [-d] [--show-path|--hide-path] [--max-string <num>] {-f <filename>|-|-- <json>}

    -p <path> is the optional path to get information about.
        If provided multiple times, the information for each path provided will be used.
        If not provided, "." is used.
    -r is an optional flag indicating that the paths provided are starting points,
        and that all paths beyond that point should also be used.
        Supplying this once will apply it to all provided paths.
        Supplying this more than once has no affect.
        If no paths are provided, all paths in the json are used.
    -d is an optional flag indicating that for objects and arrays, the pretty json should be in the output.
    --show-path is an optional flag that causes the path to be part of the output.
        This is the default when there are more than one paths.
        If supplied with --hide-path, the last one is used.
    --hide-path is an optional flag that causes the path to NOT be part of the output.
        This is the default when there is only one path.
        If supplied with --show-path, the last one is used.
    --max-string <num> is the optional maximum width for strings to trigger truncation.
        If set to 0, no truncation will happen.
        If not provided, and tput is available, then the default is to use tput to get the width of the window.
        If not provided, and tput is not available, the default is to not truncate strings.
        If the path is being shown, the length of the path is taken into consideration in order to try to
        truncate the string and keep it on a single line.

    Exactly one of the following must be provided to define the input json.
        -f <filename> will load the json from the provided filename
        - indicates that the json should be collected from stdin.
        -- <json> allows the json to be provided as part of the command.
            Everything after -- is treated as part of the json.

EOF
)"
    local input_count paths_in input_file input_stdin input show_path recurse max_string show_data
    input_count=0
    paths_in=()
    while [[ "$#" -gt '0' ]]; do
        case "$1" in
        -h|--help|help)
            printf '%s\n' "$usage"
            return 0
            ;;
        -p|--path)
            if [[ -z "$2" ]]; then
                printf 'No path provided after %s\n' "$1" >&2
                return 1
            fi
            paths_in+=( "$2" )
            shift
            ;;
        -r|--recurse|--recursive)
            recurse='yes'
            ;;
        -d|--data|--show-data)
            show_data='yes'
            ;;
        --show-path|--show-paths)
            show_path="yes"
            ;;
        --hide-path|--hide-paths)
            show_path="no"
            ;;
        --max-string)
            if [[ -z "$2" ]]; then
                printf 'No number provided after %s\n' "$1" >&2
                return 1
            fi
            max_string="$( sed 's/^[[:space:]]+//; s/[[:space:]]$//;' <<< "$2" )"
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
            printf 'Unknown argument: %s\n' "$1" >&2
            return 1
            ;;
        esac
        shift 2> /dev/null
    done
    # Make sure only one input method was provided.
    if [[ "$input_count" -eq '0' ]]; then
        printf 'No input.\n' >&2
        return 1
    elif [[ "$input_count" -ge '2' ]]; then
        printf 'Only one input can be defined.\n' >&2
        return 1
    fi
    # If it's a file, make sure it exists.
    if [[ -n "$input_file" ]]; then
        if [[ -d "$input_file" ]]; then
            printf 'Input file [%s] is a directory.\n' "$input_file" >&2
            return 1
        elif [[ ! -f "$input_file" ]]; then
            printf 'Input file [%s] does not exist.\n' "$input_file" >&2
            return 1
        fi
    fi
    # If it's stdin, get it now and then treat it as if provided by --.
    if [[ -n "$input_stdin" ]]; then
        input="$( cat - )"
        input_stdin=''
    fi

    # Make sure the max_string is a number.
    if [[ -n "$max_string" && ! "$max_string" =~ ^[[:digit:]]+$ ]]; then
        printf 'Invalid max string number: [%s].\n' "$max_string" >&2
        return 1
    fi

    local exit_code jq_filter paths jpath esc_path paths_str jq_args jq_max_string jq_output blank_path jq_exit_code line_count
    # Make sure that the provided json is okay.
    if [[ -n "$input_file" ]]; then
        jq '.' "$input_file" > /dev/null
        exit_code=$?
    else
        jq '.' <<< "$input" > /dev/null
        exit_code=$?
    fi
    if [[ "$exit_code" -ne '0' ]]; then
        printf 'Invalid json.\n' 2>&1
        return $exit_code
    fi

    # Figure out the actual paths to use.
    # In order to handle paths that have spaces or other weird stuff, I'm putting them all in a string first instead of an array.
    # Later each line will be read out and put back into an array.
    paths_str=''
    jq_filter='path(..)|reduce .[] as $item (""; if ($item|type) == "number" or ($item|@json|test("\\\\")) then . + "[" + ($item|@json) + "]" else . + "." + $item  end ) | if . == "" then "." elif .[0:1] != "." then "." + . else . end'
    if [[ "${#paths_in[@]}" -eq '0' ]]; then
        # If no paths were provided, either just use '.' or get them all.
        if [[ -z "$recurse" ]]; then
            printf -v paths_str '.\n'
        elif [[ -n "$input_file" ]]; then
            paths_str="$( jq -r "$jq_filter" "$input_file" 2> /dev/null )"
        elif [[ -n "$input" ]]; then
            paths_str="$( jq -r "$jq_filter" <<< "$input" 2> /dev/null )"
        fi
    else
        # One or more paths were provided loop through each and either add it or add it and all sub-paths.
        for jpath in "${paths_in[@]}"; do
            if [[ -z "$recurse" ]]; then
                printf -v paths_str '%b%b\n' "$paths_str" "$jpath"
            elif [[ -n "$input_file" ]]; then
                esc_path="$( sed 's/[\/&]/\\&/g' <<< "$jpath" )"
                printf -v paths_str '%b%b\n' "$paths_str" "$( jq -r "$jpath | $jq_filter" "$input_file" 2> /dev/null | sed "s/^\./$esc_path/" )"
            elif [[ -n "$input" ]]; then
                esc_path="$( sed 's/[\/&]/\\&/g' <<< "$jpath" )"
                printf -v paths_str '%b%b\n' "$paths_str" "$( jq -r "$jpath | $jq_filter" <<< "$input" 2> /dev/null | sed "s/^\./$esc_path/" )"
            fi
        done
    fi

    # Convert each path line into an array entry.
    paths=()
    while IFS= read -r jpath; do
        if [[ -n "$jpath" ]]; then
            paths+=( "$jpath" )
        fi
    done <<< "$paths_str"

    # Handle the default show path behavior and make sure that $show_path is either "yes" or empty.
    if [[ -z "$show_path" && "${#paths[@]}" -gt '1' ]]; then
        show_path='yes'
    elif [[ "$show_path" != 'yes' ]]; then
        show_path=''
    fi

    # A max width of 0 is treated as deactivating the max-width behavior.
    if [[ -z "$max_string" ]]; then
        # If no max string width was given, look for a FZF_PREVIEW_COLUMNS value.
        # If we have one, limit the string to 5 lines in the preview window.
        # Otherwise, try to set it using tput.
        if [[ -n "$FZF_PREVIEW_COLUMNS" ]]; then
            max_string=$(( FZF_PREVIEW_COLUMNS * 5 ))
        elif command -v 'tput' > /dev/null 2>&1; then
            max_string="$( tput cols )"
            if [[ "$max_string" -lt "$min_trunc" ]]; then
                # If the window is skinnier than the minimum truncation width, skip truncation.
                max_string=0
            elif [[ -n "$show_path" ]]; then
                # If showing the path, make sure none of them are so long that there wouldn't be much room left for a string.
                # If there is one that's too long, don't auto-truncate anything.
                for jpath in "${paths[@]}"; do
                    if [[ "$(( max_string - ${#jpath} - ${#path_delim} ))" -lt "$min_trunc" ]]; then
                        max_string=0
                        break
                    fi
                done
            fi
        else
            max_string=0
        fi
    fi

    # Alright. It's showtime. Loop through each path and get the info for it.
    exit_code=0
    for jpath in "${paths[@]}"; do
        jq_max_string="$max_string"
        if [[ -n "$show_path" ]]; then
            printf '%s%s' "$jpath" "$path_delim"
            if [[ "$max_string" -gt '0' ]]; then
                jq_max_string=$(( max_string - ${#jpath} - ${#path_delim} ))
                if [[ "$jq_max_string" -lt "1" ]]; then
                    jq_max_string=1
                fi
            fi
        fi
        jq_args=( -r --arg max_string_str "$jq_max_string" )
        printf -v jq_filter '($max_string_str|tonumber) as $max_string |
def null_info:    "null";
def boolean_info: "boolean: " + (.|tostring);
def number_info:  "number: " + (.|tostring);
def string_info:  "string: " + (.|@json| if $max_string == 0 or (.|length) <= ($max_string - 8) then . elif $max_string <= 11 then "..."  else (.[0:$max_string-11] + "...") end );
def array_info:   "array: " + (.|length|tostring) + " " + (if (.|length) == 1 then "entry" else "entries" end ) + ": " +
                  ([.[]|type] | reduce .[] as $item ([]; if (.|contains([$item])|not) then . + [$item] else . end) | tostring | gsub("[\\\\]\\\\[\\"]"; "") | gsub(","; " "));
def object_info:  "object: " + (.|length|tostring) + " " + (if (.|length) == 1 then "key" else "keys" end ) + ": " + (.|keys_unsorted|tostring);
%s | if (.|type) == "null" then (.|null_info)
   elif (.|type) == "boolean" then (.|boolean_info)
   elif (.|type) == "number" then (.|number_info)
   elif (.|type) == "string" then (.|string_info)
   elif (.|type) == "array" then (.|array_info)
   elif (.|type) == "object" then (.|object_info)
   else ""
end' "$jpath"
        if [[ -n "$input_file" ]]; then
            jq_output="$( jq ${jq_args[@]} "$jq_filter" "$input_file" 2> /dev/null )"
            jq_exit_code=$?
        elif [[ -n "$input" ]]; then
            jq_output="$( jq ${jq_args[@]} "$jq_filter" <<< "$input" 2> /dev/null )"
            jq_exit_code=$?
        fi
        if [[ "$jq_exit_code" -eq '0' ]]; then
            line_count="$( wc -l <<< "$jq_output" )"
            if [[ -n "$show_path" && "$line_count" -gt '1' ]]; then
                blank_path="$( sed 's/./ /g' <<< "$jpath" )   "
                # The path has already been printed, just print the first line
                head -n 1 <<< "$jq_output"
                # Now print the rest of the lines with the blank path appended.
                tail -n +2 <<< "$jq_output" | sed "s/^/$blank_path/"
            else
                printf '%s\n' "$jq_output"
            fi
            if [[ -n "$show_data" && "$line_count" -eq '1' && "$jq_output" =~ ^(object|array) ]]; then
                if [[ -n "$input_file" ]]; then
                    jq "$jpath" "$input_file" 2> /dev/null
                elif [[ -n "$input" ]]; then
                    jq "$jpath" <<< "$input" 2> /dev/null
                fi
            fi
        else
            printf 'Invalid path.\n'
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
cannot_export_f="$( export -f json_info )"
if [[ -n "$cannot_export_f" ]]; then
    export json_info="$( sed 's/^json_info ()/()/' <<< "$cannot_export_f" )"
else
    export -f json_info
fi
unset cannot_export

return 0
