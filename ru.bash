function ru() {
####################################################################
# ru - a bash function that lets you save/run commands
# It is similar to jo
#
# HOW IT WORKS:
#    Files are stored in $HOME/ru directory ($HOME/ru more precisely)
#
# @author relipse
# @license Dual License: Public Domain and The MIT License (MIT)
#        (Use either one, whichever you prefer)
# @version 1.0
####################################################################
	# Reset all variables that might be set
	local verbose=0
	local list=0
	local rem=""
	local add=0
	local adddir=""
    local allsubcommands="--list -l, --add -a, --help -h ?, -r -rm, -p --mkp"
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
	            echo "    <foo> or <foo>/more/path - cd to dir stored in contents of file $HOME/ru/<foo> (normal usage) "
	            echo "    --show|-s <foo>        - echo command"
	            echo "    --list|-l              - show run files, (same as 'ls $HOME/ru') "
	            echo "    --add|-a <sn> [<path>] - add/replace <sn> shortname to $HOME/ro with jump path <path> or current dir if not provided."
	            echo "    --rm|-r <sn>           - remove/delete short link."
	            return 0      # This is not an error, User asked help. Don't do "exit 1"
	            ;;
	        -s | --show)
	            printpath=1
	            shift
	            ;;
	        -l | --list)
				echo $(ls $HOME/ru)
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
	            	echo Invalid usage. Correct usage is: ru --add '<sn> [<path>]'
	            	return 0
	            fi

	            #by default add current pwd, if not given
	            if  [[ -n $3 ]]; then
	            	adddir=$3
	            	shift 1
	            else
	            	adddir=$(pwd)
	            fi

	            if [ ! -d $adddir ]; then
	            	echo "Warning: directory $adddir does not exist."
	            fi
	            shift 2
	            ;;
        	--add=*)
	            add=${1#*=}        # Delete everything up till "="
	            #by default add current pwd, if not given
	            if [[ -n $3 ]]; then
	            	adddir=$3
	            	shift 1
	            else
	            	adddir=$(pwd)
	            fi

	            if [ ! -d $adddir ]; then
	             	echo "Warning: directory $adddir does not exist."
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

    if  [[ "$adddir" ]]; then
        echo "$adddir" > $HOME/ru/"$add"
        if [ -f $HOME/ru/"$add" ]; then
        	echo "$add - $adddir added, try: ru $add"
        else
         	echo "problem adding $add"
        fi
        return 0;
    fi

	if (( list > 0 )); then
	    echo "Listing rus:"
		local lsjos=$(ls $HOME/ru)
		if [[ "$lsjos" ]]; then
		   echo $lsjos
		else
		   echo There are not yet any rus. try for example: ru --add foo ls -al
		fi
		return 0
	fi

	local file=$HOME/ru/"$1"
	if [ -f "$file" ]; then
		local fullpath=$(cat $file)
		if [[ "$printpath" -eq 1 ]];
		then
		    printf "%s" $fullpath
		    return 0
		fi
    		echo "$fullpath"
    		eval "time $fullpath"
	else
	 	local possible=$(ls $HOME/ru | grep $1)
                if [[ $possible ]]; then
                        echo Did you mean: $possible
                fi
		#ls $HOME/ru | grep $1
	fi
}
###############################################################endru