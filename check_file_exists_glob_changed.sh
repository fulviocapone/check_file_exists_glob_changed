#!/bin/bash
#####################################################################################
# Sample Nagios plugin to check if file(s) exists in specific folder                #
# Author: Fulvio Capone                                                             #
#####################################################################################

VERSION="Version 1.0"
AUTHOR="2015 Fulvio Capone (fulvio.capone@gmail.com)"

PROGNAME=`type $0 | awk '{print $3}'`  # search for executable on path
PROGNAME=`basename $PROGNAME`          # base name of program

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Helper functions #############################################################

function print_revision {
   # Print the revision number
   echo "$PROGNAME - $VERSION - AUTHOR"
}

function print_usage {
   # Print a short usage statement
   echo "Usage: $PROGNAME [-v] -w <limit> -c <limit> -f <file name> [-m \"<file changed in the last N minutes>\"]"
}

function print_help {
   # Print detailed help information
   print_revision
   echo "$AUTHOR\n\nCheck number of files changed in the last N minutes. OK if there is no files.\n"
   print_usage

   /bin/cat <<__EOT

Options:
-h
   Print detailed help screen
-V
   Print version information
-w INTEGER
   Exit with WARNING status if less than INTEGER of PIDS Active
-c INTEGER
   Exit with CRITICAL status if less than INTEGER of PIDS Active
-f STRING
   The name of the file(s) to check
-m INTEGER
   Minutes  
-v
   Verbose output
__EOT
}

# Main #########################################################################

# Global variables #############################################################
# Verbosity level
verbosity=0
# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=
# File(s) name
file=""
# Path of files
dir=""
# Minutes
minutes=0
# Number of files found
numfiles=0

# Parse command line options ###################################################
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -V | --version)
           print_revision
           exit $STATE_OK
           ;;
       -v | --verbose)
           : $(( verbosity++ ))
           shift
           ;;
       -w | --warning | -c | --critical)
           if [[ -z "$2" || "$2" = -* ]]; then
               # Threshold not provided
               echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
           elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is a number
               thresh=$2
           else
               # Threshold is not a number
               echo "$PROGNAME: Threshold must be integer"
               print_usage
               exit $STATE_UNKNOWN
           fi
           [[ "$1" = *-w* ]] && thresh_warn=$thresh || thresh_crit=$thresh
           shift 2
           ;;
	   -f | --file)
			if [[ -z "$2" || "$2" = -* ]]; then
			# File name not provided
			echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
		   elif [[ "$2" = /* ]]; then
               # File have absolute path
			   dir=$(dirname "${2}")
			   file=${2##*/}
           else
               # Threshold is neither a number nor a percentage
               echo "$PROGNAME: File must be a string with absolute path. You are entered the value: $2"
               print_usage
               exit $STATE_UNKNOWN
           fi
		   shift 2
		   ;;
	   -m | --minutes)
			if [[ -z "$2" || "$2" = -* ]]; then
               # Minutes not provided
               echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
           elif [[ "$2" = +([0-9]) ]]; then
               # Minutes is a number
               minutes=$2
           else
               # Minutes is not a number
               echo "$PROGNAME: Minutes must be integer"
               print_usage
               exit $STATE_UNKNOWN
           fi
		   shift 2
		   ;;
       -?)
           print_usage
           exit $STATE_OK
           ;;
       *)
           echo "$PROGNAME: Invalid option '$1'"
           print_usage
           exit $STATE_UNKNOWN
           ;;
   esac
done

# Check warning and critical thresholds
if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
   # One or both thresholds were not specified
   echo "$PROGNAME: Threshold not set"
   print_usage
   exit $STATE_UNKNOWN
elif [[ "$thresh_warn" -gt "$thresh_crit" ]]; then
   # The critical threshold must be greater or equal than the warning threshold
   echo "$PROGNAME: Critical ($thresh_crit) number of files should be greater than warning ($thresh_warn) number of files"
   print_usage
   exit $STATE_UNKNOWN
fi

# verbosity
if [[ "$verbosity" -ge 1 ]]; then
   # Print debugging information
   /bin/cat <<__EOT
Debugging information:
  Warning threshold: $thresh_warn
  Critical threshold: $thresh_crit
  Verbosity level: $verbosity
  Dir: $dir
  File(s): $file
  Minutes: $minutes
__EOT
fi

if [[ $minutes != 0 ]]; then
	echo "only files changed in the last $minutes minutes"
	FILES=`find $dir -name $file -mmin -$minutes`
else
	echo "all files"
	FILES=`find $dir -name $file`
fi

if [[ -z ""$FILES"" ]]; then
  echo "File(s) not found."
  exit $STATE_OK
else
  echo "Files found."
  for FILE in $FILES; do
	(( numfiles++ ))
    echo "File: $FILE"
  done
  if [[ "$numfiles" -ge "$thresh_crit" ]]; then
	   # Number of files found is greater than the critical threshold
	   echo "CRITICAL - $numfiles files found."
	   exit $STATE_CRITICAL
	elif [[ "$numfiles" -ge "$thresh_warn" ]]; then
	   # Number of files found greater than the warning threshold
	   echo "WARNING - $numfiles files found."
	   exit $STATE_WARNING
	else
	   # Number of files found is less than the warning threshold!
	   echo "OK - $numfiles files found."
	   exit $STATE_OK
	fi
fi
