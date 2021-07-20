#!/bin/bash
# This file installs the json_info, json_search and json_explorer functions in your environment.
# This file is meant to be sourced (e.g. in your .bash_profile).
#

# Determine if this script was invoked by being executed or sourced.
( [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" =~ :file$ ]] \
  || [[ -n "$KSH_VERSION" && $(cd "$(dirname -- "$0")" && printf '%s' "${PWD%/}/")$(basename -- "$0") != "${.sh.file}" ]] \
  || [[ -n "$BASH_VERSION" ]] && (return 0 2>/dev/null) \
) && sourced='YES' || sourced='NO'

if [[ "$sourced" != 'YES' ]]; then
    >&2 cat << EOF
This script is meant to be sourced instead of executed.
Please run this command to enable the functionality contained in within: $( printf '\033[1;37msource %s\033[0m' "$( basename "$0" 2> /dev/null || basename "$BASH_SOURCE" )" )
EOF
    exit 1
fi
unset sourced

je_install_where_i_am="$( cd "$( dirname "${BASH_SOURCE:-$0}" )"; pwd -P )"

je_install_source_command_file () {
    local cmd cmd_fn source_exit
    cmd="$1"
    cmd_fn="$je_install_where_i_am/$cmd.sh"
    if [[ -f "$cmd_fn" ]]; then
        source "$cmd_fn"
        source_exit=$?
        if [[ "$source_exit" -ne '0' ]]; then
            printf 'The command [source "%s"] exited with code [%d]\n' "$cmd_fn" "$source_exit" >&2
            return $source_exit
        elif ! command -v "$cmd" > /dev/null 2>&1; then
            printf 'The file [%s] was found and sourced, but the [%s] function is not available.\n' "$cmd_fn" "$cmd" >&2
            return 1
        fi
    else
        printf 'The file [%s] was looked for, but not found. The [%s] function could not be loaded.\n' "$cmd_fn" "$cmd" >&2
        return 1
    fi
    return 0
}

je_install_exit_code=0
je_install_source_command_file 'json_info' || je_install_exit_code=$?
je_install_source_command_file 'json_search' || je_install_exit_code=$?
je_install_source_command_file 'json_explorer' || je_install_exit_code=$?

unset je_install_where_i_am
unset -f je_install_source_command_file

# Trick: String expansion creates the proper return command, then eval unsets the je_install_exit_code variable before returning as desired.
eval "unset je_install_exit_code; return $je_install_exit_code"
