#!/bin/bash
# This file contains the json_search function that uses jq to get paths to values matching a query.
# This file can be sourced to add the json_search function to your environment.
# This file can also be executed to run the json_search function without adding it to your environment.
#
# File contents:
#   json_search  --> Outputs paths to values matching a query.
#

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

json_search () {
    if ! command -v "jq" > /dev/null 2>&1; then
        printf 'Missing required command: jq\n' >&2
        jq
        return $?
    fi
    local usage
    usage="$( cat << EOF
json_search - Searches json and returns paths and/or values for values that match a query.

Usage: json_search {-q <query>|--query <query>} [--flags <flags>] {-f <filename>|-|-- <json>}
                   [-p <path>] [--show-values|--hide-values|--just-values] [-d <delim>|--delimiter <delim>]

    -q <query> or --query <query> is search to perform.
        It is provided to jq as the val in a test(regex; flags) test.
        Each value is compared as a string. So a <query> of "true" will match strings that have "true"
            in it as well as boolean values that are set to true.
        If provided multiple times, only the last one will be used.

    --flags <flags> is an optional argument that lets you define the flags to use in the jq regex test.
        If supplied multiple times, only the last one will be used.
        If not supplied, no flags are used.

    Exactly one of the following must be provided to define the input json.
        -f <filename> will load the json from the provided filename
        - indicates that the json should be collected from stdin.
        -- <json> allows the json to be provided as part of the command.
            Everything after -- is treated as part of the json.

    -p <path> is the optional base path to start the search from.
        If provided multiple times, each provided path will be searched.
        If not provided, "." is used.

    --show-values is an optional flag that causes the value of each path to be part of the output.
        This is the default behavior.
    --hide-values is an optional flag that causes the value of each path to NOT be part of the output.
    --just-values is an optional flag that causes output to be just the values found (without the paths).

    If multiple arguments are --show-values, --hide-values or --just-values, only the last one will be used.

    -d <delim> or --delimiter <delim> defines the delimiter to use between each path and value.
        It is only applicable with --show-values (or default behavior) and will be ignored for --hide-values or --just-values.
        The default is ": ".

    See https://stedolan.github.io/jq/manual/#RegularexpressionsPCRE for jq regex and flag details.

EOF
)"
    local input_count paths_in input_file input_stdin input show_values delim query flags
    input_count=0
    paths_in=()
    show_values='yes'
    delim=': '
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
        --show-value|--show-values)
            show_values='yes'
            ;;
        --hide-value|--hide-values)
            show_values=''
            ;;
        --just-value|--just-values)
            show_values='only'
            ;;
        -d|--delim|--delimiter)
            if [[ -z "$2" ]]; then
                printf 'No delimiter provided after %s\n' "$1" >&2
                return 1
            fi
            delim="$2"
            shift
            ;;
        -q|--query)
            if [[ -z "$2" ]]; then
                printf 'No query provided after %s\n' "$1" >&2
                return 1
            fi
            query="$2"
            shift
            ;;
        --flag|--flags)
            # We want to allow "" to be provided here.
            if [[ "$#" -eq '1' ]]; then
                printf 'No flags provided after %s\n' "$1" >&2
                return 1
            fi
            flags="$2"
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
    # Make sure we have a query.
    if [[ -z "$query" ]]; then
        printf 'No query.\n' >&2
        return 1
    fi
    # Make sure the flags are alright.
    if [[ ! "$flags" =~ ^[gimnpslx]*$ ]]; then
        printf 'Illegal flag(s): %s\n' "$( sed 's/[gimnpslx]//g' <<< "$flags" )" >&2
        return 1
    fi

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

    # If no paths were provided, use .
    if [[ "${#paths_in[@]}" -eq '0' ]]; then
        paths_in=( '.' )
    fi

    local exit_code jq_filter_to_path_func jq_filter_search jq_filter_output output invalid_paths jpath jq_args jq_output jq_exit_code
    # Make sure that the provided json is okay.
    if [[ -n "$input_file" ]]; then
        jq '.' "$input_file" > /dev/null
        exit_code=$?
    else
        jq '.' <<< "$input" > /dev/null
        exit_code=$?
    fi
    if [[ "$exit_code" -ne '0' ]]; then
        printf 'Invalid json.\n' >&2
        return $exit_code
    fi

    # Define a jq function to turn a paths array into a path string. The jq invocation must also have a --arg base "<path>" argument provided.
    jq_filter_to_path_func='def to_path: reduce .[] as $item (""; if ($item|type) == "number" or ($item|@json|test("^\"[a-zA-Z_][a-zA-Z0-9_]*\"$")|not) then . + "[" + ($item|@json) + "]" else . + "." + $item end ) | if . == "" then $base elif $base == "." and .[0:1] == "." then . else $base + . end;'
    # Define the search part of the filter. The jq invocation must also have a --arg query "<query>" argument provided.
    printf -v jq_filter_search '. as $dot | path(..| select((scalars or . == null) and (tostring|test($query;"%s"))) )' "$flags"
    # Define the output manipulation part of the filter. Input at this point will be an array of scalars from the paths function.
    # This assumes that $dot was previously set in the filter.
    # The jq invocation should also have a --arg delim "<delim>" argument provided.
    if [[ -z "$show_values" ]]; then
        jq_filter_output='to_path'
    elif [[ "$show_values" == 'yes' ]]; then
        jq_filter_output='. as $p | ($p|to_path) + $delim + ($dot|getpath($p)|@json)'
    elif [[ "$show_values" == 'only' ]]; then
        jq_filter_output='. as $p | ($dot|getpath($p)|@json)'
    else
        printf 'Unknown show_values value: %s\n' "$show_values" >&2
        return 1
    fi

    # And let's get to it.
    output=''
    invalid_paths=()
    for jpath in "${paths_in[@]}"; do
        printf -v jq_filter '%s %s | %s | %s' "$jq_filter_to_path_func" "$jpath" "$jq_filter_search" "$jq_filter_output"
        jq_args=( -r --arg base "$jpath" --arg query "$query" --arg delim "$delim" "$jq_filter" )
        jq_output=''
        if [[ -n "$input_file" ]]; then
            jq_output="$( jq "${jq_args[@]}" "$input_file" 2> /dev/null )"
            jq_exit_code=$?
        elif [[ -n "$input" ]]; then
            jq_output="$( jq "${jq_args[@]}" <<< "$input" 2> /dev/null )"
            jq_exit_code=$?
        fi
        if [[ "$jq_exit_code" -eq '0' ]]; then
            printf -v output '%s%s\n' "$output" "$jq_output"
        else
            invalid_paths+=( "$jpath" )
            exit_code=$jq_exit_code
        fi
    done
    sort -u <<< "$output" | grep '[^[:space:]]'
    if [[ "${#invalid_paths[@]}" -gt '0' ]]; then
        { printf '\n'; printf 'Invalid path: %s\n' "${invalid_paths[@]}"; } >&2
    fi
    return $exit_code

}

if [[ "$sourced" != 'YES' ]]; then
    json_search "$@"
    exit $?
fi
unset sourced
cannot_export_f="$( export -f json_search )"
if [[ -n "$cannot_export_f" ]]; then
    export json_search="$( sed 's/^json_search ()/()/' <<< "$cannot_export_f" )"
else
    export -f json_search
fi
unset cannot_export_f

return 0
