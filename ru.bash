#!/bin/bash

#############################################################################
# ru - a utility that lets you save/run commands (kind of like a new set of
# aliases)
# @see https://github.com/relipse/ru
#
# It is similar to jo (https://github.com/relipse/jojumpoff_bash_function)
#
# HOW IT WORKS:
#    Files are stored in ~/.ru
#
# INSTALL
# 1. chmod a+x this script
# 2. Copy this script to a directory in your PATH
# 3. For command completion add this to your ~/.bashrc:
#     eval "$(ru --bash-completion)"
# 4. ru -a <sn> <cmd>
# 5. For example: ru -a lsal ls -al
# 6. ru lsal
#
#
# BUGS
#   Currently --verbose doesn't do anything.
#
# @author relipse
# @license Dual License: Public Domain and The MIT License (MIT)
#        (Use either one, whichever you prefer)
# @version 1.2
####################################################################

# external command depenencies:
#	rm

# exit code cheatsheet:
#	1 - argument parse error
#	2 - general failure
#	3 - command not found
#	4 - command name collision

usage () {
	printf '%s\n' "Usage: $(appname) [-ars] NAME COMMAND [COMMAND-ARG...]
save commands by name and then later run them

  -s|--show NAME            run saved command named by NAME
  -l|--list                 list available commands
  -a|--add NAME COMMAND     add NAME as a shortcut for COMMAND
  -c|--cd NAME PATH         save NAME a a shortcut for changing to PATH
  -p|--mkdir                when running a command added with -c, create the
                            directory if it does not exist
  -r|--rm NAME              remove/delete saved shortcut
  -t|--time                 time the runtime of the command
      --bash-completion     eval-able code to set up completion
      --setup-cd            eval-able code to make --cd commands work
  -v|--verbose              produce more messages
  -V|--version              display version information and exit
  -h  --help                display this help text and exit

Arguments following -a NAME are part of the command to be saved, but if one
of the arguments is ';' it ends the command instead and any remaining
arguments are processed as usual.

If you wish to pass extra arguments to a saved command at run time they will
be added to the end of the saved command line. If the arguments begin with
a - character you must specify -- before those arguments so they are not
interpreted as arguments to $(appname).

Switches can be specified in any combination and order, but --add cannot be
specified more than once in a single invocation.
"
}

version () {
	printf '%s: version 1.2\n' "$(appname)"
}

stderr () {
	# shellcheck disable=SC2059
	printf "$@" 1>&2
}

appname () {
	printf '%s\n' "${BASH_SOURCE[0]##*/}"
}

try-help () {
	usage | head -n 1
	printf "Try '%s --help' for more information.\n" "$(appname)"
}

unrecognized-option () {
	printf	"%s: unrecognized option '%s'\n"  "$(appname)" "$1"
	try-help
}

if ! command -v fold >/dev/null; then
	# polyfill: a subset of fold with just enough functionality
	fold () {
		local width=80 str

		while [[ ${#@} -gt 0 ]] ; do
			case "$1" in
				-w|--width)
					shift
					width="$1"
				;;
				-w*)
					width="${1:2}"
				;;
				*)
					break
				;;
			esac
			shift
		done

		if read -t 0 -u 0; then
			while IFS= read -u 0 -r -n "$width" str ; do
				if [[ ${#str} -eq 0 ]]; then
					break
				fi
				printf '%s\n' "$str"
			done
		fi
	}
fi

if ! command -v head >/dev/null; then
	head () {
		local lines=10 line
		while [[ ${#@} -gt 0 ]] ; do
			case "$1" in
				-n|--lines)
					shift
					lines="$1"
				;;
				-n*)
					lines="${1:2}"
				;;
				*)
					break
				;;
			esac
			shift
		done

		# of course this can block forever, but it won't
		while IFS=$'\n' read -u 0 -r line ; do
			if ((lines-- == 0)); then
				break
			fi
			printf '%s\n' "$line"
		done
	}
fi


ru-bash-completion () {
	local commands=(RUCONFDIR/*)
	COMPREPLY+=("${commands[@]##*/}")
}

setup-completion () {
	local fn
	fn=$(declare -pf ru-bash-completion)
	fn="${fn/RUCONFDIR/$ruconfdir}"
	printf '%s\ncomplete -F ru-bash-completion %s\n' "$fn" "$(appname)"
}

list () {
	local file fullcommand
	for file in "$ruconfdir"/*; do
		printf '%s\n' "${file##*/}"
		printf '\t%s\n' "$(show-full-command "$file")"
	done
}

show-full-command () {
	local command="$1" fullcommand
	mapfile -t fullcommand < "$command"
	fullcommand=("${fullcommand[@]:1}")
	printf '%s\n' "${fullcommand[*]%' "$@"'}"
}

list-possible-commands () {
	local command possible
	if (( $# )); then
		for command; do
			printf 'No exact match for "%s"\n' "$command"

			possible=("$ruconfdir"/*"$command"*)
			if (( ${#possible[@]} )); then
				printf 'Possible matches:\n'
				printf '\t%s\n' "${possible[@]##*/}"
			fi
		done
	else
		possible=("$ruconfdir"/*)
		printf '%s\n' "${possible[@]##*/}"
	fi
}

remove () {
	local path rc=0
	for command; do
		path="$ruconfdir/$command"
		if ! [[ -f $path ]]; then
			stderr '%s: no such saved command: %s\n' "$(appname)" "$command"
			list-possible-commands "$command" 1>&2
			rc="$e_bad_command"
			continue
		fi
		if (( verbose > 1 )); then
			printf 'Removing %s -> %s\n' "$command" "$(show-full-command "$path")"
		elif (( verbose > 0 )); then
			printf 'removed %s\n' "$command"
		fi
		rm -f -- "$path"
	done
	return "$rc"
}

add () {
	ensure-confdir || return $?

	local command args=() arg
	for arg; do
		if [[ -z $command ]]; then
			command="$arg"
		elif [[ $arg == ';' ]]; then
			add-one "$command" "${args[@]}"
			unset command args
		else
			args+=("$arg")
		fi
	done
	if (( ${#args[@]} )); then
		add-one "$command" "${args[@]}"
	fi
}

add-one () {
	local command="$1"
	shift

	local command_path="$ruconfdir"/"$command"

	if [[ -f $command_path ]]; then
		stderr '%s: saved command %s already exists\n' "$(appname)" "$command"
		stderr 'to add a command with this name first remove the existing one by running\n\t%s --rm %s\n' "$(appname)" "$command"
		return "$e_command_exists"
	fi

	if printf '#!/bin/bash\n%s "$@"\n' "$*" > "$command_path"; then
		chmod a+x "$command_path"
		if (( verbose > 2 )); then
			printf '%s - %s addedtry ru %s\n' "$command" "$*" "$command"
		elif (( verbose > 1 )); then
			printf 'added %s: %s\n' "$command" "$*"
		elif (( verbose > 0 )); then
			printf 'added %s\n' "$command"
		fi
	else
		stderr '%s: problem adding %s\n' "$(appname)" "$command"
		return "$e_fail"
	fi
}

add-path () {
	local command path
	for path; do
		if [[ -z $command ]];then
			command="$path"
		else
			printf '%s\n' "$path" > "$ruconfdir/$command"
			unset command
		fi
	done
}

ensure-confdir () {
	local rc
	mkdir -p "$ruconfdir" || {
		rc=$?
		stderr '%s: unable to create %s\n' "$(appname)" "$ruconfdir"
		return "$rc"
	}
}

run-command () {
	local command="$1" cmd_path rc path
	shift
	cmd_path="$ruconfdir/$command"
	if [[ -x $cmd_path ]]; then
		# command
		if (( show )); then
			printf '%s %s\n' "$cmd_path" "$*"
		else
			if (( time )); then
				time "$cmd_path" "$@"
			else
				"$cmd_path" "$@"
			fi
		fi
	elif [[ -f $cmd_path ]]; then
		# non-excutable directory path
		path="$(<"$cmd_path")"
		if (( show )); then
			printf '%s cd %s\n' "$command" "$path"
		else
			if (( mkdir )); then
				# mkdir may fail if e.g. the target path exists
				# and is a non-dir
				mkdir -p "$path" 2>/dev/null || {
					rc=$?
					stderr '%s: unable to auto-create %s\n' "$path"
					return "$rc"
				}
			fi

			# the path might be relative. If it is then cd will
			# fail later.
			printf '%s\n' "$path"
			return 99
		fi
	else
		list-possible-commands "$command" 1>&2
		return "$e_bad_command"
	fi
}

# wrapper to make --cd commands appear to work
inline-ru () {
	local output
	output=$(command APPNAME "$@")
	if (( $? == 99 )); then
		cd "$path" || $?
	else
		printf '%s\n' "$output"
	fi
}

setup-inline-ru () {
	local fn
	fn=$(declare -pf inline-ru)
	fn="${fn/APPNAME/$(appname)}"
	printf '%s\nalias %s="inline-ru"\n' "$fn" "$(appname)"
}


shopt -s nullglob

e_bad_arg=1
e_fail=2
e_bad_command=3
e_command_exists=4

ruconfdir=~/.ru
show=
list=
remove=()
add=()
add_path=
setup_completion=
verbose=0
time=
mkdir=
version=
help=

if ! (( $# )); then
	try-help 1<&2
	list-possible-commands 1>&2
	exit "$e_bad_arg"
fi

no_more_options=
non_option_args=()
while (( $# )); do
	if (( no_more_options )) ; then
		non_option_args+=("$1")
		shift
		continue
	fi
	case "$1" in
		-s|--show)
			show=1
		;;
		-l|--list)
			list=1
		;;
		-r|--rm)
			shift
			remove+=("$1")
		;;
		-a|--add)
			shift
			if [[ -z $1 ]] || [[ -z $2 ]]; then
				stderr '%s: --add requires at least two parameters\n'
				try-help
				exit "$e_bad_arg"
			fi
			for cmdarg; do
				add+=("$cmdarg")
				if [[ $cmdarg == ';' ]]; then
					break
				fi
				shift
			done
		;;
		-c|--cd)
			shift
			add_path+=("$1" "$2")
			shift
		;;
		--setup-cd)
			setup_cd=1
		;;
		-t|--time)
			time=1
		;;
		-p|--mkdir)
			mkdir=1
		;;
		--bash-completion)
			setup_completion=1
		;;
		-v|--verbose)
			((verbose++))
		;;
		-h|--help|'-?')
			help=1
		;;
		-V|--version)
			version=1
		;;
		--)
			no_more_options=1
		;;
		--*)
			unrecognized-option "$1"
			exit "$e_bad_arg"
		;;
		-*)
			if [[ -z $unbundled ]] ; then
				# unbundle short options
				mapfile -t short < <(fold -w 1 <<<"${1:1}")
				set -- "${short[@]/#/-}" "${@:2}"
				unset short
				unbundled=1
				continue
			else
				unrecognized-option "$1"
				exit "$e_bad_arg"
			fi
		;;
		*)
			non_option_args+=("$1")
		;;
	esac
	shift
	unset unbundled
done

if (( help )); then
	usage
	exit 0
fi

if (( version )) ; then
	version
	exit 0
fi

if (( setup_completion )); then
	setup-completion
	exit 0
fi

if (( setup_cd )); then
	setup-inline-ru
	exit 0
fi


if (( list )); then
	list
	exit 0
fi

if (( ${#remove[@]} )); then
	remove "${remove[@]}"
fi

if (( ${#add[@]} )); then
	add "${add[@]}"
fi

if (( ${#add_path[@]} )); then
	add-path "${add_path[@]}"
fi

if (( ${#non_option_args[@]} )); then
	# user requested to run a saved command
	run-command "${non_option_args[@]}"
fi
