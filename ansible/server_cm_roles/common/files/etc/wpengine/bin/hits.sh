#!/bin/bash
# Author: Marty Bowers
# Date: 9/2/2014
# Purpose: count hits for the last n hours for a site
# Change Log:
# - Initial Release

read -r -d '' USAGE <<USAGE_BLOCK
# Usage: hits.sh <site> <hours> <partial_hour>
#   site (text): install name used in /var/log/nginx
#   hours (integer): number of full hours to go back
#   partial_hour (boolean): 0 means include current partial hour, 1 means don't
USAGE_BLOCK

if [ $# -lt 3 ]; then
    echo "$USAGE"
    exit 1
fi

SITE=$1
HOURS=$2
PARTIAL=$3
TOTAL=0

if [ $PARTIAL -eq 0 ]; then
 echo -n "Hits during the previous $HOURS full hours (including the current partial hour): "
 while [ $HOURS -ge 0 ]; do
  DATE=`date +"%d/%b/%Y:%H" --date="$HOURS hours ago"`
  HITS=`zgrep $DATE /var/log/nginx/$SITE.access.log* | wc -l`
  TOTAL=`echo "$TOTAL + $HITS" | bc`
  HOURS=$((HOURS-1))
 done
else
 echo -n "Hits during the previous $HOURS full hours (NOT including the current partial hour): "
 while [ $HOURS -gt 0 ]; do
  DATE=`date +"%d/%b/%Y:%H" --date="$HOURS hours ago"`
  HITS=`zgrep $DATE /var/log/nginx/$SITE.access.log* | wc -l`
  TOTAL=`echo "$TOTAL + $HITS" | bc`
  HOURS=$((HOURS-1))
 done
fi
echo "$TOTAL"
