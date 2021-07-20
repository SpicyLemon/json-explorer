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

Usage: json_info [-p <path>] [-r] [-d] [--show-path|--hide-path|--just-paths] [--max-string <num>] {-f <filename>|-|-- <json>}

    -p <path> is the optional path to get information about.
        If provided multiple times, the information for each path provided will be used.
        If not provided, "." is used.

    -r is an optional flag indicating that the paths provided are starting points,
        and that all paths beyond that point should also be used.
        Supplying this once will apply it to all provided paths.
        Supplying this more than once has no extra affect.
        If no paths are provided, all paths in the json are used.

    -d is an optional flag indicating that for objects and arrays, the pretty json should be in the output.

    --show-path is an optional flag that causes the path to be part of the output.
        This is the default when there are more than one paths.
    --hide-path is an optional flag that causes the path to NOT be part of the output.
        This is the default when there is only one path.
    --just-paths is an optional flag that causes only the paths to be output (without the extra information).

    If multiple arguments are --show-path, --hide-path, or --just-paths, only the last one will be used.

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
            show_path='yes'
            ;;
        --hide-path|--hide-paths)
            show_path='no'
            ;;
        --just-path|--just-paths)
            show_path='only'
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

    local exit_code jq_func_from_path paths_arrays jpath jq_exit_code check_str_len jq_args jq_filter
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

    # Define a jq function to go from a path string to a paths array.
    jq_func_from_path='def from_path: sub("^\\.$";"[]") | gsub("\\.(?<k>[a-zA-Z_][a-zA-Z0-9_]*)";"[\"\(.k)\"]") | sub("^\\.";"") | gsub("]\\[";",") | fromjson;'

    #Use jq to check all provided paths, convert them to paths arrays and combine them all into a json array.
    if [[ "${#paths_in[@]}" -eq '0' ]]; then
        # No paths provided. [] is the array form of .
        paths_arrays='[[]]'
    else
        paths_arrays='[]'
        for jpath in "${paths_in[@]}"; do
            printf -v jq_filter '%s %s | [$base | from_path] | $paths_arrays + .' "$jq_func_from_path" "$jpath"
            if [[ -n "$input_file" ]]; then
                paths_arrays="$( jq -c --arg base "$jpath" --argjson paths_arrays "$paths_arrays" "$jq_filter" "$input_file" )"
                jq_exit_code=$?
            elif [[ -n "$input" ]]; then
                paths_arrays="$( jq -c --arg base "$jpath" --argjson paths_arrays "$paths_arrays" "$jq_filter" <<< "$input" )"
                jq_exit_code=$?
            fi
            if [[ "$jq_exit_code" -ne '0' ]]; then
                printf 'Invalid path: %s\n' "$jpath" >&2
                return $jq_exit_code
            fi
        done
    fi

    check_str_len=''
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
                check_str_len='yes'
            fi
        else
            max_string=0
        fi
    fi

    jq_args=( --arg recurse "$recurse" --arg show_path "$show_path" --arg show_data "$show_data" --arg path_delim "$path_delim" )
    jq_args+=( --arg check_str_len "$check_str_len" --argjson max_string "$max_string" --argjson min_trunc "$min_trunc" )
    if [[ -n "$input_file" ]]; then
        jq_args+=( --slurpfile data "$input_file" )
    elif [[ -n "$input" ]]; then
        jq_args+=( --argjson data "[$input]" )
    fi

    jq_filter='def null_info:    "null";
def boolean_info: "boolean: " + (.|tostring);
def number_info:  "number: " + (.|tostring);
def string_info($max_info_string):  "string: " + (.|@json| if $max_info_string == 0 or (.|length) <= ($max_info_string - 8) then . elif $max_info_string <= 11 then "..."  else (.[0:$max_info_string-11] + "...") end );
def array_info:   "array: " + (.|length|tostring) + " " + (if (.|length) == 1 then "entry" else "entries" end ) + ": " +
                  ([.[]|type] | reduce .[] as $item ([]; if (.|contains([$item])|not) then . + [$item] else . end) | tostring | gsub("[\\]\\[\"]"; "") | gsub(","; " "));
def object_info:  "object: " + (.|length|tostring) + " " + (if (.|length) == 1 then "key" else "keys" end ) + ": " + (.|keys_unsorted|tostring);
def get_info($max_info_string_len): if (.|type) == "null" then (.|null_info)
   elif (.|type) == "boolean" then (.|boolean_info)
   elif (.|type) == "number" then (.|number_info)
   elif (.|type) == "string" then (.|string_info($max_info_string_len))
   elif (.|type) == "array" then (.|array_info)
   elif (.|type) == "object" then (.|object_info)
   else "unknown type"
end;
def to_path: reduce .[] as $item ("";
    if ($item|type) == "number" or ($item|@json|test("^\"[a-zA-Z_][a-zA-Z0-9_]*\"$")|not) then
        . + "[" + ($item|@json) + "]"
    else
        . + "." + $item
    end
) | if . == "" then "." elif .[0:1] != "." then "." + . else . end;

$data[0] as $data |
if $recurse == "yes" then [.[]|. as $base|$data|getpath($base)|path(..)|$base+.] else . end |
(if $show_path == "" and (.|length) > 1 then "yes" else $show_path end) as $show_path |
[.[]|{arr:.}] |
if $show_path == "yes" or $show_path == "only" then [.[]|.str=(.arr|to_path)] else . end |
(if $check_str_len == "yes" and ($max_string - ([.[]|.str|length]|max) - ($path_delim|length)) < $min_trunc then 0 else $max_string end) as $max_string |

.[] | . as $path |
if $show_data == "yes" or $show_path != "only" then .data=($data|getpath($path.arr)) else . end |
if $show_path == "yes" then
    .info=(.data|get_info($max_string - ($path_delim|length) - ($path.str|length)))
elif $show_path != "only" then
    .info=(.data|get_info($max_string))
else . end |
.output = [] |

if $show_path == "only" then
    .output += [.str]
elif $show_path == "yes" then
    .output += [.str + $path_delim + .info]
else
    .output += [.info]
end |
if $show_data == "yes" and ((.data|type) == "array" or (.data|type) == "object") then .output += [.data] else . end |
.output[]'

    jq -r "${jq_args[@]}" "$jq_filter" <<< "$paths_arrays"
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
