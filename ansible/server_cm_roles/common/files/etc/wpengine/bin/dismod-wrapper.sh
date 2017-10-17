#!/bin/bash
# WPE wrapper file around PHP module disable, phpdismod/php5dismod.
# Used to integrate with our ansible provisioning (server-cm) for idempotency.

# php5query (Ubuntu 12.04 and 14.04, php5-common provided)
# List modules: php5query -M
# List modules and enabled/disabled status: php5query -M -v
# List SAPIs (cli, cgi, apache2): php5query -S
# Show status of individual module and SAPI: php5query -s cli -m json
#  Ex: json (Enabled for cli by maintainer script)
#  Ex: No module matches json (Disabled for cli by maintainer script)

# phpquery (Ubuntu 14.04 (php 7.0), 16.04, php-common provided)
# List versions (5.5, 5.6, 7.0): phpquery -V
# List module available for version: phpquery -M -v 5.5
# List module available for all versions: phpquery -M -v ALL
# Show status of invididual module on SAPI: phpquery -v 7.0 -s cli -m json
#  Ex: json (Enabled for cli by maintainer script)
#  Ex: No module matches json (Disabled for cli by local administrator)

# $1 is module name
# $2 is sapi (apache2, cli, cgi)

if [[ $# -eq 0 ]] ; then
  echo "USAGE: $0 <module> [sapi|ALL] [version|ALL]"
  exit -1
fi

MODULE="${1}"
SAPI="${2:-ALL}"
VERSION="${3:-ALL}"

if [[ "${VERSION^^}" == "ALL" ]] || [[ "${VERSION}" == 5 ]] || [[ "${VERSION}" == *"5.5"* ]] ; then
  php5query -S 2>/dev/null | while read -r S ; do
    if [[ "${SAPI^^}" == "ALL" ]] || [[ "${SAPI,,}" == "${S,,}" ]] ; then
      before=$(php5query -s "${S}" -m "${MODULE}" 2>/dev/null | grep -c Enabled)
      php5dismod -s "${S}" "${MODULE}" &>/dev/null
      after=$(php5query -s "${S}" -m "${MODULE}" 2>/dev/null | grep -c Enabled)
      [[ ${before} -ne ${after} ]] && [[ ${after} -eq 0 ]] && echo "Disabled ${MODULE} for php5 ${S}"
    fi
  done
fi

phpquery -V 2>/dev/null | while read -r V ; do
  if [[ "${VERSION^^}" == "ALL" ]] || [[ "${VERSION}" == "${V}" ]] ; then
    phpquery -v "${V}" -S | while read -r S ; do
      if [[ "${SAPI^^}" == "ALL" ]] || [[ "${SAPI,,}" == "${S,,}" ]] ; then
        before=$(phpquery -v "${V}" -s "${S}" -m "${MODULE}" 2>/dev/null | grep -c Enabled)
        phpdismod -v "${V}" -s "${S}" "${MODULE}" &>/dev/null
        after=$(phpquery -v "${V}" -s "${S}" -m "${MODULE}" 2>/dev/null | grep -c Enabled)
        [[ ${before} -ne ${after} ]] && [[ ${after} -eq 0 ]] && echo "Disabled ${MODULE} for php ${V} ${S}"
      fi
    done
  fi
done
exit 0
