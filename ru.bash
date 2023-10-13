#!/bin/bash

myrucompletion () {
	# I have removed trailing semicolons that are not required
	# this is a style choice and my preference, but not important
	local f

	# Quote *EVERY* expansion. It is never enough.
	# The dir I am checking is now ~/.ru (see below for why)
	for f in ~/.ru/"$2"*; do
		# within [[ expressions certain expansions do not need to be
		# quoted. If you are unsure which require it then it is safe
		# to quote all of them. I am not correcting this one because
		# it does not require it.
		[[ -f $f ]] && COMPREPLY+=( "${f##*/}" )
	done
}

complete -F myrucompletion ru

####################################################################
# ru - a bash function that lets you save/run commands (kind of
# like a new set of aliases)
# @see https://github.com/relipse/ru
#
# It is similar to jo (https://github.com/relipse/jojumpoff_bash_function)
#
# HOW IT WORKS:
#    Files are stored in $HOME/ru directory ($HOME/ru more precisely)
# INSTALL
# 1. mkdir ~/ru
# 2. Copy this whole function up until ##endru into your ~/.bashrc
# 3. source ~/.bashrc
# 4. ru -a <sn> <cmd>
# 5. For example: ru -a lsal "ls -al"
# 6. ru lsal
#
# @author relipse
# @license Dual License: Public Domain and The MIT License (MIT)
#        (Use either one, whichever you prefer)
# @version 1.2
####################################################################

# you should use either:
#	function foo { ... }
# OR
# 	foo () { ... }
# you should not mix them.
# Most people prefer the latter form for declarations, and it's more portable
ru () {
	local verbose=0
	local list=0
	local rem=""
	local add=0
	local addcmd=""
	local allsubcommands="--list -l, --add -a, --help -h ?, -r -rm"
	local mkdirp=""
	local mkdircount=0
	local printpath=0
	local args=()

	# several things:
	# * use variables to avoid repeating information
	# * program generated content is more usually stored in dotfiles
	#   (these days you could also consider using XDG dirs e.g. ~/.share)
	# * there is no need to say $HOME, ~ is necessarily the same thing.
	local ruconfdir=~/.ru
	mkdir -p "$ruconfdir"

	# you can simplify the check for "are there any args" to this
	if ! (( $# )); then
		# you should NEVER use echo in scripts
		# printf replaced echo in the *1980s* and echo is both
		# obsolete and potentially dangerous
		printf 'Try %s --help for more, but here are the existing rus:\n' "${BASH_SOURCE[0]}"
		ls "$HOME"/ru
		printf 'ru arguments: %s\n' "$allsubcommands"

		# this seems potentially like an error condition since the
		# call that was made was invalid. Consider returning non-zero
		# here. Consider GNU tools e.g. grep when run without args;
		# they print a similar message and exit non-zero.
		return 0
	fi

	# instead of looping forever you can, since you are shifting, simply
	# loop until the argument list is empty. This requires only a slight
	# change to how you handle arguments (in your *) case) and is a style
	# I find virtuous
	while (( $# )); do
		case $1 in
			-h | --help | -\?)
				#  Call your Help() or usage() function here.

				# I usually use a here doc to keep usage
				# more readable. You should also consdider
				# reformatting usage since tradition dictates
				# that it should wrap at 80 columns (or 78
				# if you are being conservative).
				cat <<HELP
Usage: ru <foo>, where <foo> is a file in $ruconfdir containing the full directory path.
Ru Command line arguments:
    <foo>                  - run command stored in contents of file $ruconfdir<foo> (normal usage) 
    --show|-s <foo>        - echo command
    --list|-l              - show run files with commands
    --add|-a <sn> [<path>] - add/replace <sn> shortname to $ruconfdir with jump path <path> or current dir if not provided.
    --rm|-r <sn>           - remove/delete short link.
HELP
				return 0	# This is not an error, User asked help. Don't do "exit 1"
			;;
			-s | --show)
				printpath=1
				shift
			;;
			-l | --list)
				printf 'Listing rus:\n'

				# all variables you use in a funtion should be
				# declared as "local". Also, all-caps
				# variable names should only be used for
				# environment variables or, more strictly,
				# are reserved for use by POSIX and should not
				# be used at all.
				local file
				for file in "$ruconfdir"/*; do
					# this parameter expansion is
					# equivalent to basename but cheaper
					printf '%s\n' "${file%/*}"
					cat "$file"
				done
				return 0
			;;
			-r | -rm | --rm)
				if [[ -n $2 ]]; then
					rem=$2
				else
					# errors should be emitted on stderr
					printf "Invalid usage. Correct usage is: ru --rm '<sn>'\n" 1>&2
					# in the case of an error the exit
					# code should be non-zero
					return 1
				fi
				shift 1
			;;
			-a | --add)
				if [[ -n $2 ]]; then
					add=$2	# You might want to check if you really got FILE
				else
					printf "Invalid usage. Correct usage is: ru --add '<sn> <cmd>'\n" 1>&2
					return 1
				fi
				if  [[ -n $3 ]]; then
					addcmd=$3
					shift 1
				fi
				shift 2
			;;
			--add=*)
				add=${1#*=}	# Delete everything up till "="
				#by default add current pwd, if not given
				if [[ -n $3 ]]; then
					addcmd=$3
					shift 1
				fi
				shift 1
			;;
			-v | --verbose)
				# Each instance of -v adds 1 to verbosity

				# you can increment this way; if the variable
				# had been uninitialized its value becomes 1
				((verbose++))
				shift
			;;
			--) # End of all options
				shift
				args+=("$@")
				break
			;;
			-*)
				printf "WARN: Unknown option (ignored): %s\n" "$1" >&2
				shift

				# it would be more usual for this case to be
				# treated as a fatal error and abort here
			;;
			*)
				# collect remaining args
				args+=("$1")
				shift
			;;
		esac
	done

	# I don't like [[ $var ]] for checking for non-empty string; there is
	# an operator specifically for that which adds clarity and doesn't
	# rely on an accident of grammar
	if [[ -n $rem ]]; then
		# again, avoid repeating information
		local rempath="$ruconfdir/$rem"
		# you should always prefer [[ to [ in bash scripts
		if [[ -f $rempath ]]; then
			# instead of $(cat file) you can do $(<file) and get
			# the same result more efficiently
			printf 'Removing %s -> %s\n' "$rem" "$(<"$rempath")"
			rm "$rempath"
		else
			printf '%s does not exist\n' "$rem"

			# you can avoid two extra subprocesses by letting bash
			# match with a glob
			# I am evaluating this in a subshell so that nullglob
			# doesn't persist and I don't need to check if you had
			# it turned on already
			(
				shopt -s nullglob
				local possible=("$ruconfdir"/*"$rem"*)
				if (( ${#possible[@]} )); then
					printf 'Did you mean %s\n' "${possible[@]}"
				fi
			)
		fi
		return 0
	fi

	if  [[ -n $addcmd ]]; then
		printf '%s\n' "$addcmd" > "$ruconfdir"/"$add"
		if [[ -f $ruconfdir/$add ]]; then
			printf '%s - %s added, try ru %s\n' "$add" "$addcmd" "$add"
		else
			# this looks like an error to me, so stderr
			printf 'problem adding %s\n' "$add" 1>&2
		fi
		return 0
	fi

	local file="$ruconfdir/${args[0]}"

	# switched to [[ at which point $file need not be quoted
	if [[ -f $file ]]; then
		# quoting $file here is necessary for safety
		local fullcmd
		fullcmd=$(< "$file")

		# use (( aka numeric context for numeric comparison. I left
		# your logic as-is, but if printpath is intended as a boolean
		# you can just say: if (( printpath )); then
		if (( printpath == 1 )); then
			# there is no need to double quote printf patterns
			# I left this without a trailing newline, but there
			# are few reasons I can think of why you would want to
			# omit one.
			printf '%s' "$fullcmd"
			return 0
		fi
		printf '%s\n' "$fullcmd"

		# 'eval' should be avoided at all costs! Danger lies here.
		eval "time $fullcmd"
	else
		(
			shopt -s nullglob
			local possible=("$ruconfdir"/*"${args[0]}"*)
			if (( ${#possible[@]} )); then
				printf 'Did you mean %s\n' "${possible[@]}"
			fi
		)
	fi
}

