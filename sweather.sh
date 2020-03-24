#!/usr/bin/env bash
#########################################################################
# Name: Franklin Henriquez                                              #
# Author: Franklin Henriquez (franklin.a.henriquez@gmail.com)           #
# Creation Date: 04Apr2019                                              #
# Last Modified: 05Apr2019                                              #
# Description:	Gets weather information for USA, this is using the 	#
#               https://www.weather.gov/documentation/services-web-api  # 
#                                                                       #
# Version: 0.1.0                                                        #
#                                                                       #
#########################################################################

#set -o errexit
#set -o pipefail
set -o nounset
# set -o xtrace

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" 

# DESC: Generic script initialisation
# ARGS: None
function script_init() {
    # Useful paths
    readonly orig_cwd="$PWD"
    readonly script_path="${BASH_SOURCE[0]}"
    readonly script_dir="$(dirname "$script_path")"
    readonly script_name="$(basename "$script_path")"

    # Important to always set as we use it in the exit handler
    readonly ta_none="$(tput sgr0 || true)"
}

# DESC: Initialise color variables
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

    return 0
}

# DESC: Usage help
# ARGS: None
function usage() {
    echo -e "
    \rUsage: ${__base} \"location\" [options]
    \rDescription:\t 3 Day forecast for US location.

    \rrequired arguments:
    \r<location>\tLocation name.

    \roptional arguments:
    \r-d|--day\t\tDay's forecast.
    \r-h|--help\t\tShow this help message and exit.
    \r-t|--hourly\t\tDay's hourly forecast.
    \r-w|--week\t\tWeek's forecast.
    "
}

# DESC: Parameter parser
# ARGS: $@ (optional): Arguments provided to the script
function parse_params() {
    local param
    while [[ $# -gt 0 ]]; do
        #param="${1}"
        params=$(echo ${1})

        # Getting the last parameter which should be the news_id.
        news_id=$(echo $params | awk 'NF>1{print $NF}')
        shift
        # Iterate through all the parameters.
        for param in $(echo ${params})
        do
            case $param in
                -d|--day)
                    day=1
                    ;;
               -h|--help)
                    usage
                    exit 0
                    ;;
               -t|--hourly)
                    hourly=1
                    ;;
               -w|--week)
                    week=1
                    ;;
                -*)
                    usage
                    echo -e "${IYellow}Invalid Parameter${Color_Off}:" \
                        "${IRed}${param}${Color_Off}"
                    exit 0
                    ;;
                *)
					usage
                    exit 0
                    ;;
                esac
        done
    done
}

# DESC: Print Location info.
# ARGS: $1 (required): Array of location info as json.
#       $2 (optional): Exit code (defaults to 0)
function print_location_info(){

	info=$1
	
	if [[ ${day} -eq 1 ]]
	then
		echo ${info} | \
            jq '.properties.periods[:2]' | \
            jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
	elif [[ ${week} -eq 1 ]]
	then
		echo ${info} | \
            jq '.properties.periods' | \
            jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
	elif [[ ${hourly} -eq 1 ]]
	then
		echo ${info} | \
            jq '.properties.periods[:9]' | jq -r '.[] | "\(.startTime)
        \r\(.temperature) \(.temperatureUnit) degrees 
        \rwith a \(.windDirection) wind at \(.windSpeed)
        \r\(.shortForecast)\n"'
	else 
		echo ${info} | \
            jq '.properties.periods[:6]' | \
            jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
	fi
	
	return 0
}
# DESC: Main control flow
# ARGS: $@ (optional): Arguments provided to the script
function main() {
    # shellcheck source=source.sh
    #source "$(dirname "${BASH_SOURCE[0]}")/bash_color_codes"

    #trap "script_trap_err" ERR
    #trap "script_trap_exit" EXIT

    script_init
    #colour_init
    echo_color_init

    # Print usage if no parameters are entered.
    if [ $# -eq 0 ]
    then
        usage
        exit 2
    fi
	
	day=0
	hourly=0
	mid_week=0
	week=0

	get_params="$@"
    query=$( echo ${get_params} | tr ' ' '\n' | grep -v '-') 
    sorted_params=$( echo ${get_params} | tr ' ' '\n' | \
        grep '-' | sort | tr '\n' ' ' | sed 's/ *$//')
    parse_params "${sorted_params}"

	# Get latitude and longtitude
	coor=$(geolocate -c "${query}, USA" | awk '{print $2}' | tr '\n' ',')

	api='https://api.weather.gov/'
	args='/points/'
	if [[ $hourly -eq 1 ]]
	then
		converter="${api}${args}${coor%?}/forecast/hourly"
	else
		converter="${api}${args}${coor%?}/forecast"
	fi

	resp=$(curl -L -X GET "${converter}" -H "accept: application/geo+json"\
        2> /dev/null) 
	
	#echo ${resp} | jq '.properties.periods[:6]' | jq -r '.[] | "\(.name): \(.detailedForecast) \n"'
	print_location_info "${resp}"
	exit 0
}

# Start main function
main "$@"
