
#!/bin/bash
USAGE=$(cat <<-END

    Make a JSON config_file_name.json with content:

[
    {
        "name": "LOG file 1",
        "path": "/path/to/log.log",
        "command": "/bin/bash somekind_scripts.sh LOG_MESSAGE",
        "timeout": 120,
        "filters":
            [
                {
                    "name": "Month",
                    "filter": "Jan",
                    "ignore": "" 
                },
                {
                    "name": "Filter Title",
                    "filter": "Filter String",
                    "ignore": "Text" 
                },
                {
                    "name": "Third filter", 
                    "filter": "Text",
                    "ignore": "Text*text2" 
                }
            ]
},
    {
        "name": "System LOG",
        "path": "/path/to/syslog",
        "command": "perl somekind_scripts.pl LOG_MESSAGE",
        "timeout": 120,
        "filters":
            [
                { "name": "Server Name", "filter": "Server", "ignore": "" },
                { "name": "Error filter", "filter": "ERR" , "ignore": "text*text2"}
            ]
    }
]

    *Note that LOG_MESSAGE which contains the log that was hit in self
     It's is not mandatory to use.
    
    How to run:
    ./script.sh config_file.json
    or
    ./path/to/script.sh /path/to/config_file.json
END
)
startWatching(){
  	LOGNR=$1 
	LOGFILE=`jq -r '.['$LOGNR'].path' "$CONFIGFILE"`
	LOGNAME=`jq -r '.['$LOGNR'].name' "$CONFIGFILE"`
	COMMAND=`jq -r '.['$LOGNR'].command' "$CONFIGFILE"`
	TIMEOUTSEC=`jq -r '.['$LOGNR'].timeout' "$CONFIGFILE"`
	FILTERCOUNT=`jq '.['$LOGNR'].filters | length' "$CONFIGFILE"`
	TIMEOUTTIME=`date +%s` 
	echo "_________________________________________________________"
	if [[ -f "${LOGFILE}" ]]; then
		echo "                    ${LOGNAME}"
    	echo "_________________________________________________________"
		echo "LogName: ${LOGNAME}"
		echo "LogFile location: ${LOGFILE}"
	    #get FILTERS and make array
	    for (( j = 0; j < $FILTERCOUNT ; j++ )); do
			fnr=$((j+1))
			#get filternames
			fname=`jq -r '.['$LOGNR'].filters['$j'].name' "$CONFIGFILE"`
    		echo "------------------"
    		echo "Filter number $fnr"
    		echo "Name: $fname"
			FILTERNAMEARRAY+=(${fname// /.})
			#get filters
    		value=`jq -r '.['$LOGNR'].filters['$j'].filter' "$CONFIGFILE"`
    		echo "Filter: '$value'"
			FILTERARRAY+=(${value// /.})
			#get ignore
    		ignore=`jq -r '.['$LOGNR'].filters['$j'].ignore' "$CONFIGFILE"`
    		echo "Ignore: '$ignore'"
			IGNOREARRAY+=(${ignore// /.})
			# sleep 5
			ignore=""
			value=""
			fname=""
			unset $value
			unset $fname
			unset $ignore
       	done
		echo "------------------"
	  	echo "$(date)"
	  	echo "Start Watching: $LOGFILE ...."
	  	echo ""
		tail -fn0 $LOGFILE | \
		while read LINE ; do
			for ((k = 0; k < $FILTERCOUNT; k++))
			do
				if [[ "$LINE" == *"${FILTERARRAY["$k"]//./ }"* && "$LINE" != *"${LOGNAME}"* ]]; then
					CURRTIME=`date +%s`
					DIFFTIME="$((CURRTIME-TIMEOUTTIME))"
					echo "_________________START ${LOGNAME} NOTIFY_________________"
					echo "Current Time: $CURRTIME"
					echo "Timeout Time: $TIMEOUTTIME"
					echo "Time Difference: $DIFFTIME"
					echo "Timeout value: $TIMEOUTSEC"
					if [[ $DIFFTIME -gt $TIMEOUTSEC ]]; then
						IFS='*' read -r -a IGNORES <<< "${IGNOREARRAY["$k"]//./ }"
						COUNT=0
						for IGNORE in "${IGNORES[@]}"
						do
							if [[ "$LINE" == *"${IGNORE//./ }"* ]]; then
								COUNT=$((COUNT+1))
							fi
						done
						if [[ $COUNT == 0 ]]; then
				        	echo "${LOGNAME} Filter Name: '${FILTERNAMEARRAY[$k]//./ }'"
				        	echo "${LOGNAME} Filter: '${FILTERARRAY[$k]//./ }'"
				        	echo "${LOGNAME} Log: $LINE"
				       		MESSAGE="${LOGNAME}: $LINE"
							MESSAGE=${MESSAGE//./ }
				        	echo "${LOGNAME} Message: $MESSAGE"
				        	echo "${LOGNAME} Command: $COMMAND"
				        	EXCECUTE="${COMMAND/LOG_MESSAGE/"\""$MESSAGE"\""}"
							eval $EXCECUTE
				        	echo "_________________END ${LOGNAME} NOTIFY___________________"
				        	TIMEOUTTIME=`date +%s`
						else
							echo "Notify cancelled due to ignore filter "
				        	echo "_________________END ${LOGNAME} NOTIFY___________________"
				        fi
					else
						echo "Notify timeout; Already notified past $TIMEOUTSEC seconds"
			        	echo "_________________END ${LOGNAME} NOTIFY___________________"
					fi
		        fi		
			done		
		done
	else
	    echo "!!!!ERROR: Log file ${LOGFILE} does not exist."
		echo "$USAGE"
	fi
}

CONFIGFILE="log_notify.json"

checkJSONelements(){
    allMainElement=("name" "path" "command" "filters" "timeout")
    allFilterElement=("name" "filter" "ignore")
    logcount=`jq -r 'length' "$CONFIGFILE"` 
    
    for (( c = 0; c < $logcount; c++ )); do
        for element in "${allMainElement[@]}"
        do
            elementValue=`jq -r ".[$c].\"$element\"" "$CONFIGFILE"`
            if [[ $elementValue == null ]]; then
                return 1 #false
                break
            fi
        done

        for element in "${allFilterElement[@]}"
        do
            elementValue=`jq -r ".[$c].filters[0].\"$element\"" "$CONFIGFILE"`
            if [[ $elementValue == null ]]; then
                return 1 #false
                break
            fi
        done
        return 0 #true 
    done
}

#######START##############
#load config file
if [[ $1 == */* ]]; then
	CONFIGFILE=$1
else
	PARENT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
	CONFIGFILE=$PARENT_PATH/$1
fi
echo "Processing Config file: $CONFIGFILE"
if [[ -f "$CONFIGFILE" ]]; then
	if jq -e . >/dev/null 2>&1 <<< cat "$CONFIGFILE"; then
	    
	    if checkJSONelements $1 ; then
	    	sleep 3
		    echo "Config JSON file Valid and Complete"
			logcount=`jq -r 'length' "$CONFIGFILE"`
		    #get LOGPATH 
		    for (( i = 0; i < $logcount ; i++ )); do
		    	sleep 1
		    	startWatching $i & # Put a function in the background
			done
		else
		    echo "!!!!ERROR: Failed to parse JSON file ${LOGFILE}; Missing $element"
		    echo "$USAGE"
			exit 0
		fi
	    
	else
	    echo "!!!!ERROR: Failed to parse JSON file ${LOGFILE}"
		echo "$USAGE"
		exit 0	
	fi
else 
	echo "!!!!ERROR: Config file not present"
	echo "$USAGE"
	exit 0
fi
wait 
echo "All done"
exit 0
#######################