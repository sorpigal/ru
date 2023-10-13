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
#	cat
#	rm

usage () {
	cat <<HELP
Usage: $(appname) [-s COMMAND] | -l | -ar SHORTNAME
save and then later run commands

  -s|--show COMMAND         run saved command named by COMMAND
  -l|--list                 list available commands
  -a|--add SHORTNAME [PATH] add shortname to $ruconfdir with jump path
                            PATH (or current dir if not provided)
  -r|--rm SHORTNAME         remove/delete short link
      --bash-completion     eval-able code t set up completion
  -v|--verbose              produce more messages
      --version             display version information and exit
  -h  --help                display this help text and exit

All arguments after -a are part of the command unless an argument consisting
of ';' is specified, which ends slurping of arguments for the -a switch.

Example of saving a command:
	ru -a lsal ls -al

Example of invoking a saved command:
	ru lsal
	ru lsal /tmp
	ru lsal -- -h /tmp

Notice that if additional saved command arguments start with - they will need
to be given after -- to prevent $(appname) from detecting them.
HELP
}

version () {
	cat <<VERSION
$(appname): version 1.2
VERSION
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
	local fn=$(declare -pf ru-bash-completion)
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
			possible=("$ruconfdir"/*"$commmand"*)
			if (( ${#possible[@]} )); then
				printf 'Did you mean %s\n' "${possible[@]##*/}"
			fi
		done
	else
		possible=("$ruconfdir"/*)
		printf '%s\n' "${possible[@]##*/}"
	fi
}

remove () {
	local path
	for command; do
		path="$ruconfdir/$command"
		if ! [[ -f $path ]]; then
			stderr '%s: no such saved command: %s\n' "$(appname)" "$command"
			list-possible-commands "$command" 1>&2
			continue
		fi
		printf 'Removing %s -> %s\n' "$command" "$(show-full-command "$path")"
		rm -f -- "$path"
	done
}

add () {
	local command="$1"
	shift

	ensure-confdir || return $?

	local command_path="$ruconfdir"/"$command"
	if printf '#!/bin/bash\n%s "$@"\n' "$*" > "$command_path"; then
		chmod a+x "$command_path"
		printf '%s - %s added, try ru %s\n' "$command" "$*" "$command"
	else
		stderr '%s: problem adding %s\n' "$(appname)" "$command"
		return 1
	fi
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
	local command="$1" cmd_path
	shift
	cmd_path="$ruconfdir/$command"
	if [[ -f $cmd_path ]]; then
		if (( printpath )); then
			printf '%s %s\n' "$cmd_path" "$*"
		else
			time "$cmd_path" "$@"
		fi
	else
		list-possible-commands "$command"
		return 1
	fi
}

# expand * to nothing if there are no matches
shopt -s nullglob

ruconfdir=~/.ru
printpath=
list=
remove=()
add=
add_command=()
setup_completion=
verbose=0
version=
help=

if ! (( $# )); then
	try-help 1<&2
	list-possible-commands 1>&2
	exit 1
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
			printpath=1
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
			if [[ -n $add ]]; then
				stderr '%s: --add may not be specified more than once\n' "$(appname)"
				exit 2
			fi
			if [[ -z $1 ]]; then
				stderr '%s: invalid use of --add\n'
				try-help
				exit 2
			fi
			add=$1
			shift
			if [[ -z $1 ]]; then
				stderr '%s: --add requires at least two parameters\n'
				try-help
				exit 2
			fi
			for cmdarg; do
				if [[ $cmdarg == ';' ]]; then
					shift
					break
				fi
				add_command+=("$cmdarg")
				shift
			done
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
		--version)
			version=1
		;;
		# example of accepting a switch of the form --key value
		#--key)
		#	shift; key="$1"
		#;;
		# example of accepting a switch of the form --key=value
		# --key=*)
		#	IFS='=' read -r _ key <<<"$1"; shift

		--)
			no_more_options=1
		;;
		--*)
			unrecognized-option "$1"
			exit 1
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
				exit 1
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

if (( list )); then
	list
	exit 0
fi

if (( ${#remove[@]} )); then
	remove "${remove[@]}"
fi

if [[ -n $add ]]; then
	add "$add" "${add_command[@]}" || exit $?
fi

if (( ${#non_option_args[@]} )); then
	# user requested to run a saved command
	run-command "${non_option_args[@]}"
fi
