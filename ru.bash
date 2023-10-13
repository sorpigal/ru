myrucompletion () {
        local f;
        for f in ~/ru/"$2"*;
        do [[ -f $f ]] && COMPREPLY+=( "${f##*/}" );
        done
}

complete -F myrucompletion ru

function ru() {
####################################################################
# ru - a bash function that lets you save/run commands (kind of
# like a new set of aliases)
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
	# Reset all variables that might be set
	local verbose=0
	local list=0
	local rem=""
	local add=0
	local addcmd=""
    	local allsubcommands="--list -l, --add -a, --help -h ?, -r -rm"
	local mkdirp=""
	local mkdircount=0
	local printpath=0

	if (( $# == 0 )); then
	    #echo "Try ru --help for more, but here are the existing jos:"
		ls $HOME/ru
		#echo "Ro arguments: $allsubcommands"
	    return 0
	fi


	while :
	do
	    case $1 in
	        -h | --help | -\?)
	            #  Call your Help() or usage() function here.
	            echo "Usage: ru <foo>, where <foo> is a file in $HOME/ru/ containing the full directory path."
	            echo "Ru Command line arguments:"
	            echo "    <foo>                  - run command stored in contents of file $HOME/ru/<foo> (normal usage) "
	            echo "    --show|-s <foo>        - echo command"
	            echo "    --list|-l              - show run files with commands"
	            echo "    --add|-a <sn> [<path>] - add/replace <sn> shortname to $HOME/ro with jump path <path> or current dir if not provided."
	            echo "    --rm|-r <sn>           - remove/delete short link."
	            return 0      # This is not an error, User asked help. Don't do "exit 1"
	            ;;
	        -s | --show)
	            printpath=1
	            shift
	            ;;
	        -l | --list)
		    	echo "Listing rus:"
	     		for FILE in $HOME/ru/*;
	       		do
		        	echo $(basename -- $FILE): 
		         	cat $FILE;
	                done
			return 0
			;;
		-r | -rm | --rm)
			 if [[ -n $2 ]]; then
				rem=$2
			 else
				echo Invalid usage. Correct usage is: ru --rm '<sn>'
				return 0
			 fi
			 shift 1
			 ;;
    		 -a | --add)
    		    if [[ -n $2 ]]; then
	              add=$2     # You might want to check if you really got FILE
	            else
	            	echo Invalid usage. Correct usage is: ru --add '<sn> <cmd>'
	            	return 0
	            fi
	            if  [[ -n $3 ]]; then
	            	addcmd=$3
	            	shift 1
	            fi
	            shift 2
	            ;;
        	--add=*)
	            add=${1#*=}        # Delete everything up till "="
	            #by default add current pwd, if not given
	            if [[ -n $3 ]]; then
	            	addcmd=$3
	            	shift 1
	            fi
	            shift 1
            ;;
	        -v | --verbose)
	            # Each instance of -v adds 1 to verbosity
	            verbose=$((verbose+1))
	            shift
	            ;;
	        --) # End of all options
	            shift
	            break
	            ;;
	        -*)
	            echo "WARN: Unknown option (ignored): $1" >&2
	            shift
	            ;;
	        *)  # no more options. Stop while loop
	            break
	            ;;
	    esac
	done

	if [[ "$rem" ]]; then
		if [ -f $HOME/ru/"$rem" ]; then
			echo "Removing $rem -> $(cat $HOME/ru/$rem)"
			rm $HOME/ru/"$rem"
		else
			echo "$rem does not exist"
			local possible=$(ls $HOME/ru | grep $rem)
			if [[ $possible ]]; then
				echo Did you mean: $possible
			fi
		fi
		return 0;
	fi

	if  [[ "$addcmd" ]]; then
		echo "$addcmd" > $HOME/ru/"$add"
		if [ -f $HOME/ru/"$add" ]; then
			echo "$add - $addcmd added, try: ru $add"
		else
			echo "problem adding $add"
		fi
		return 0;
	fi

	local file=$HOME/ru/"$1"
	if [ -f "$file" ]; then
		local fullcmd=$(cat $file)
		if [[ "$printpath" -eq 1 ]];
		then
		    printf "%s" $fullcmd
		    return 0
		fi
    		echo "$fullcmd"
    		eval "time $fullcmd"
	else
	 	local possible=$(ls $HOME/ru | grep $1)
                if [[ $possible ]]; then
                        echo Did you mean: $possible
                fi
		#ls $HOME/ru | grep $1
	fi
}
###############################################################endru
