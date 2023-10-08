#!/usr/bin/env bash
#########################################################################
# Name: Franklin Henriquez                                              #
# Author: Franklin Henriquez (franklin.a.henriquez@gmail.com)           #
# Creation Date: 04Apr2019                                              #
# Last Modified: 07Oct2023                                              #
# Description:	Gets weather information for USA, this is using the 	#
#               https://www.weather.gov/documentation/services-web-api  #
#                                                                       #
# Version: 0.3.0                                                        #
#                                                                       #
#########################################################################

# Required binaries:
# Creating variable to validate binaries.
# - GNU bash 3+
REQUIRED_BINARIES="
awk
cut
curl
getopt
geolocate
grep
jq
"

# Notes:
#
#


__version__="0.3.0"
__author__="Franklin Henriquez"
__email__="franklin.a.henriquez@gmail.com"


# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)"


# Script Config Vars

# Color Codes
# DESC: Initialize color variables
# ARGS: None
function echo_color_init(){

    Color_Off='\033[0m'       # Text Reset
    NC='\e[m'                 # Color Reset

    # Regular Colors
    Black='\033[0;30m'        # Black
    Red='\033[0;31m'          # Red
    Green='\033[0;32m'        # Green
    Yellow='\033[0;33m'       # Yellow
    Blue='\033[0;34m'         # Blue
    Purple='\033[0;35m'       # Purple
    Cyan='\033[0;36m'         # Cyan
    White='\033[0;37m'        # White

    # Bold
    BBlack='\033[1;30m'       # Black
    BRed='\033[1;31m'         # Red
    BGreen='\033[1;32m'       # Green
    BYellow='\033[1;33m'      # Yellow
    BBlue='\033[1;34m'        # Blue
    BPurple='\033[1;35m'      # Purple
    BCyan='\033[1;36m'        # Cyan
    BWhite='\033[1;37m'       # White

    # High Intensity
    IBlack='\033[0;90m'       # Black
    IRed='\033[0;91m'         # Red
    IGreen='\033[0;92m'       # Green
    IYellow='\033[0;93m'      # Yellow
    IBlue='\033[0;94m'        # Blue
    IPurple='\033[0;95m'      # Purple
    ICyan='\033[0;96m'        # Cyan
    IWhite='\033[0;97m'       # White

}


# Setting up logging
exec 3>&2 # logging stream (file descriptor 3) defaults to STDERR
verbosity=3 # default to show warnings
silent_lvl=0
crt_lvl=1
err_lvl=2
wrn_lvl=3
inf_lvl=4
dbg_lvl=5
bash_dbg_lvl=6


notify() { log $silent_lvl "${Cyan}NOTE${Color_Off}: $1"; } # Always prints
critical() { log $crt_lvl "${IRed}CRITICAL:${Color_Off} $1"; }
error() { log $err_lvl "${Red}ERROR:${Color_Off} $1"; }
warn() { log $wrn_lvl "${Yellow}WARNING:${Color_Off} $1"; }
info() { log $inf_lvl "${Blue}INFO:${Color_Off} $1"; } # "info" is already a command
debug() { log $dbg_lvl "${Purple}DEBUG:${Color_Off} $1"; }
log() {
    if [ "${verbosity}" -ge "${1}" ]; then
        datestring=$(date +'%Y-%m-%d %H:%M:%S')
        # Expand escaped characters, wrap at 70 chars, indent wrapped lines
        echo -e "$datestring - __${FUNCNAME[2]}__  - $2" >&3 #| fold -w70 -s | sed '2~1s/^/  /' >&3
    fi
}


logger() {
    if [ -n "${LOG_FILE}" ]
    then
        echo -e "$1" >> "${log_file}"
        #echo -e "$1" >> "${LOG_FILE/.log/}"_"$(date +%d%b%Y)".log
    fi
}


# DESC: What happens when ctrl-c is pressed
# ARGS: None
# Trap ctrl-c and call ctrl_c()
trap ctrl_c INT


function ctrl_c() {
    info "Trapped CTRL-C signal, terminating script"
    log "\n================== $(date +'%Y-%m-%d %H:%M:%S'): Run Interrupted  ==================\n"
    # Any clean up action here
    # rm -f ${TEMP_FILE}
    exit 2
}


# DESC: Validates script has access to the specified binaries.
# ARGS:
function validate_binaries() {

    debug "Validating binaries for script."

    for req_bin in ${REQUIRED_BINARIES}
    do
        path_to_bin=$(which ${req_bin})
        validation_exit_code=$(echo $?)
        if [[ ${validation_exit_code} != 0 ]]
        then
            error "Could not locate ${req_bin} binary"
            exit 1
        else
            debug "Validating ${req_bin}::"
        fi
    done

}


# DESC: Usage help
# ARGS: None
function usage() {
    echo -e "
    \rUsage: ${__base} \"location\" [options]
    \rDescription:\t\t\t 3 Day forecast for US location.

    \rrequired arguments:
    \r<location>\t\t\t Location name.

    \roptional arguments:
    \r-d,--day\t\t\t Day's forecast.
    \r-h,--help\t\t\t Show this help message and exit.
    \r-t,--hourly\t\t\t Day's hourly forecast.
    \r-w,--week\t\t\t Week's forecast.
    \r-v,--verbose\t\t\t Verbosity.
    \r             \t\t\t\t -v info
    \r             \t\t\t\t -vv debug
    \r             \t\t\t\t -vvv bash debug
    "
    return 0
}


# DESC: Parse arguments
# ARGS: main args
function parse_args(){

    local short_opts='d,h,t,w,v'
    local long_opts='day,help,hourly,week,verbose'

    # set -x # remove comment to troubleshoot parsing args
    # -use ! and PIPESTATUS to get exit code with errexit set
    # -temporarily store output to be able to check for errors
    # -activate quoting/enhanced mode (e.g. by writing out “--options”)
    # -pass arguments only via   -- "$@"   to separate them correctly
    ! PARSED=$(getopt --options=${short_opts} --longoptions=${long_opts} --name "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        # e.g. return value is 1
        #  then getopt has complained about wrong arguments to stdout
        debug "getopt has complained about wrong arguments"
        exit 2
    fi

    # read getopt’s output this way to handle the quoting right:
    eval set -- "$PARSED"

    if [[ "${PARSED}" == " --" ]]
    then
        debug "No arguments were passed"
        usage
        exit 1
    fi

    # Getting positional args
    if [[ "${pos_arguments}" == "true" ]]; then
        OLD_IFS=$IFS
        POSITIONAL_ARGS=${PARSED#*"--"}
        IFS=' ' read -r -a positional_args <<< "${POSITIONAL_ARGS}"
        IFS=$OLD_IFS
    fi

    # extract options and their arguments into variables.
    while true ; do
        case "$1" in
            -d|--day)
                requestForecast='day'
                shift
                ;;
            -h |--help)
                # Display usage.
                usage
                exit 1;
                ;;
            -t|--hourly)
                requestForecast='hourly'
                shift
                ;;
            -w|--week)
                requestForecast='week'
                shift
                ;;
            -v | --verbose)
                (( verbosity = verbosity + 1 ))
                if [ $verbosity -eq $bash_dbg_lvl ]
                then
                    debug="true"
                fi
                shift
                ;;
            -- )
                shift
                break ;;
            * )
                usage
                exit 3
        esac
    done

    return 0
}


# DESC: Print Location info.
# ARGS: $1 (required): Array of location info as json.
#       $2 (optional): Exit code (defaults to 0)
function print_location_info(){

#     set -x
    info="$@"
    result_location=$(echo "${info}" | cut -d ';' -f 1)
    result_forecast=$(echo "${info}" | cut -d ';' -f 2)

    if [ ${#results[@]} -gt 1 ]
    then
        echo -e "${IYellow}${result_location}${Color_Off} Forecast ::"
    fi

    case "$requestForecast" in
        day)
            debug "Printing today's forecast: ${result_location}"
    		echo ${result_forecast} | \
                jq '.properties.periods[:2]' | \
                jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
         ;;
        week)
            debug "Printing weekly forecast: ${result_location}"
    		echo ${result_forecast} | \
                jq '.properties.periods' | \
                jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
            ;;
        hourly)
            debug "Printing today's hourly forecast: ${result_location}"
            echo ${result_forecast} | \
                jq '.properties.periods[:9]' | jq -r '.[] | "\(.startTime)
            \r\(.temperature) \(.temperatureUnit) degrees
            \rwith a \(.windDirection) wind at \(.windSpeed)
            \r\(.shortForecast)\n"'
            ;;
        *)
            debug "Printing 3 day forecast: ${result_location}"
            echo "${result_forecast}" | \
                jq '.properties.periods[:6]' | \
                jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
          ;;
    esac

	return 0
}


# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
function main() {

    # Any default values go here
    debug="false"
    verbose="false"
    pos_arguments="true"
    # pos_arguments="false"
    requestForecast='3days'

    echo_color_init
    parse_args "$@"

    debug "
    bash_debug:     \t ${debug}
    positional_args:\t ${pos_arguments}
    verbosity:      \t ${verbosity}
    "

    # Getting positional arguments
    if [[ "${pos_arguments}" == "true" ]]; then
        OLD_IFS=$IFS
        IFS=' ' read -r -a pos_args <<< "${POSITIONAL_ARGS[@]}"
        IFS=${OLD_IFS}
        if [[ $(echo ${pos_args[@]} | grep -c '\-\-') -gt 0 ]]
        then
            debug "Getting property ${pos_args[@]}"
            # Getting everything to the right of the '--'
            tmp="${pos_args[@]}"
            IFS=' ' read -r -a pos_args <<< "${tmp#*"--"}"
            IFS=${OLD_IFS}
        fi

        # debug "$(echo ${pos_args[@]})"
    fi

    # Run in debug mode, if set
    if [ "${debug}" == "true" ]; then
        set -o noclobber
        set -o errexit          # Exit on most errors (see the manual)
        set -o errtrace         # Make sure any error trap is inherited
        set -o nounset          # Disallow expansion of unset variables
        set -o pipefail         # Use last non-zero exit code in a pipeline
        set -o xtrace           # Trace the execution of the script (debug)
    fi

    # Validating required variables.
    #if [ -z "${required_var:-}" ]
    #then
    #    usage
    #    exit 3
    #fi


    # Validate required binaries for script
    validate_binaries

    debug "Starting script"

    # Main
	api='https://api.weather.gov/points/'

    declare -a results

    # Positional parameters are validated here.
    # if not need you can remove
    if [[ "${pos_arguments}" == "true" ]]; then
        pos_arg_count=0
        len=${#pos_args[@]}
        if [[ ${len} == 0 ]]
        then
            error "No positional argument passed."
            usage
            exit 1
        else
            while [ $pos_arg_count -lt $len ];
            do
                query="${pos_args[${pos_arg_count}]}"
                debug "Fetching coordinates for ${query}"

                coor=$(geolocate -c "${query}" | grep 'Lat\|Long' | awk '{print $2}' | tr '\n' ,)

                lat=$(printf "%2.4f\n" "$(echo $coor | awk -F ',' '{print $1}')")
                lon=$(printf "%2.4f\n" "$(echo $coor | awk -F ',' '{print $2}')")

                coor="${lat},${lon}"

                # Get latitude and longitude
                # The precision of latitude/longitude points is limited to 4 decimal
                # digits for efficiency. The location attribute contains your request
                # mapped to the nearest supported point.

	            resp=$(curl -L -X GET "${api}${coor%?}" -H "accept: application/geo+json"\
                2> /dev/null)

                if [[ "${requestForecast}" == "hourly" ]]
                then
                    debug "Getting hourly forecast."
                    forecast_query=$(echo "${resp}" | cut -d  ';' -f 2 | 
                        jq -r '.properties.forecastHourly')
                else
                    debug "Getting forecast."
		            converter="${api}${coor%?}/forecast"
                    forecast_query=$(echo "${resp}" | cut -d  ';' -f 2 | 
                        jq -r '.properties.forecast')
                fi

                forecast=$(curl ${forecast_query} 2>/dev/null)
                results+=("${query};${forecast}")

                pos_arg_count=$((${pos_arg_count}+1))
            done
        fi
    else
        debug "No position arguments to work with"
        results+=($(echo "$@"))
    fi

    for result in "${results[@]}"
    do
	    print_location_info ${result}
    done

    return 0
}

# Start main function
main "$@"

exit 0
