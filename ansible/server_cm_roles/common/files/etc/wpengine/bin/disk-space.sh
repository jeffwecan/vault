#!/bin/bash
# DISK SPACE UTIL
# instructions 

usage="$(basename "$0") [-h] [-y] [-s] -- This script will help identify and fix disk space issues
	where:
		-h  show this help text
		-y  force answer 'yes' to all prompts
		-n  force answer 'no' to all prompts 
		-s  check site plans
"
skipsitecheck=1
force=0

#is -y specified
while getopts "hysn" opt ; do
	if [[ $opt = "h" ]]; then echo "$usage"; exit; fi
	if [[ $opt = "y" ]]; then force=1; fi
	if [[ $opt = "n" ]]; then force_no=1; fi
	if [[ $opt = "s" ]]; then skipsitecheck=0; fi
done

#Some of these processes are heavy on io, don't want to interfer with the system
ionice -c2 -n6 -p$$
renice 19 $$

clear
echo -e "/////// DISK SPACE ISSUE FINDER/FIXER /////// "

	## WE NEED SOME FUNCTIONS 
	function print_error {
		error=${1:?"Must specify error"}
		echo -e "\033[31m$error \033[0m"
	}

	function print_warning {
		warning=${1:?"Must specify warning"}
		echo -e "\033[33m$warning \033[0m"
	}

	function print_success {
		success=${1:?"Invalid Message"}
		echo -e "\033[32m$success \033[0m"
	}

	function success_message {
		bold=$(tput bold)
		normal=$(tput sgr0)
		message=$1
		echo "\033[32m${bold}$message \033[0m${normal}"
	}

	function error_message {
		bold=$(tput bold)
		normal=$(tput sgr0)
		message=$1
		echo "\033[31m${bold}$message \033[0m${normal}"
	}	

	function size_status {
		pctused=$1
		part=$2
		if [[ $pctused -gt 90 ]]; then 
			print_error "\nCRITICAL: Disk Space on $part is less than 10%. $(( 100 - pctused))% available \n"
		elif [[ $pctused -gt 80 ]]; then
			print_warning "\nWARNING: Disk Space on $part is less than 20%. $(( 100 - pctused))% available \n"
		else
			print_success "\nOK: Disk Space on $part is fine. $(( 100 - pctused))% available\n"
		fi
	}

if [[ $( pgrep "$0" | wc -l ) -gt 2 ]] > /dev/null; then
	print_error "$0 already running!!!"
	exit
fi

if [[ $TERM != "screen" ]]; then
	print_error "Not running in screen!!!"
	exit
fi

if [[ $( pgrep rsync | wc -l ) -gt 0 ]]; then
	print_warning "rsync is running, someone is probably pushing to staging"
fi

if [[ $( pgrep git | wc -l ) -gt 0 ]]; then
	print_warning "git is running, git is probably filling the disk with a commit"
fi

pctused=$( df -h / | awk 'FNR == 2 {sub(/\%$/,"",$5); print $5}' )
spaceused=$( df / | awk 'FNR == 2 {print $3}' )
partition=$( df / | awk 'FNR == 2 {print $NF}' )

size_status "$pctused" "$partition"

#Check and make sure / is really the problem
if [[ "$pctused" -gt 75 ]]; then 
	if [ -d "/root/.cache/duplicity/" ]; then
		echo -e "Cleaning duplicity cache ... \n"
		find /root/.cache/duplicity/ -type f -mtime +7 -delete
	fi
	
	if [ -d "/var/cache/eaccelerator/" ]; then
		echo -e "Cleaning eAccelerator cache"
		find /var/cache/eaccelerator/ -type f -mtime +7 -delete
	fi

	echo -e "Cleaning wp-all-import-pro"
	find /tmp -name 'wp-all-import-pro' | awk -F"/" '{print $2}' | xargs -n100 -I{} rm -vrf {}
	
	echo -e "Removing old magick files from /tmp"
	find /tmp -maxdepth 1 -type f -name "magick-*" -mtime +7 -exec rm -f {} \;
	
	if [ -d "/var/lib/nginx/proxy/" ]; then
		echo -e "Cleaning Nginx proxy cache from /var/lib/nginx/proxy/"
		find /var/lib/nginx/proxy/ -type f -mtime +7 -delete
	fi
	
	# Temporarily bypass this part per request from Dustin Meza
	#echo -e "Removing old staging content files"
	#nice rm -rvf /nas/wp/www/staging/*/wp-content/uploads/2011 /nas/wp/www/staging/*/wp-content/uploads/2012 /nas/wp/www/staging/*/wp-content/uploads/2013/0* /nas/wp/www/staging/*/wp-content/blogs.dir/*/files/2011 /nas/wp/www/staging/*/wp-content/blogs.dir/*/files/2012 /nas/wp/www/staging/*/wp-content/blogs.dir/*/files/2013/0*
	
	echo -e "\n\nChecking /tmp \n"
	du /tmp/ | sort -rn | head | awk '{
		if ( int($1) > 1024*1024 )
		printf("\t \033[31m%dM\033[0m %s \n",$1,$2);
	}'
	
	echo -e "\n\nChecking logs \n"
	
		logs=$( find /var/log/ -type f -print0 | xargs -0 ls -s | sort -rn | awk '{size=$1/1024; printf("%d %s\n", size,$2);}' | head )
		toplog=$( echo "$logs" | head -n1 | awk '{print $1}' )
	
	if [[ $toplog -gt 1000 ]]; then 
		print_error "\tLarge logs found"
		echo "$logs"
	else
		print_success "\tNo large logs found"
	fi
	
	#I'm disabling this because I haven't seen this long get this big and there are better ways to do this
	#If this is a problem it will be displayed in the check logs and can be manually dealt with
	#if [[ $( du /var/log/varnish/varnishncsa.log | awk '{print $1}' ) -gt $(( 1024 * 1024 * 1024 )) ]]; then
	#	print_error "\tvarnishnca too big $( du /var/log/varnish/varnishncsa.log )"
	#	service varnishncsa stop
	#	killall /usr/bin/varnishncsa
	#	sleep 1
	#	killall -9 /usr/bin/varnishncsa
	#	while [[ $( pgrep varnishncsa ) ]]; do echo "waiting" && sleep 1; done
	#	service varnish restart
	#	service varnishncsa start
	#	print_success "\tvarnishncsa cleaned"
	#fi
fi

# This rarely trims enough space to be considered worthwhile.
# We should seriously consider getting rid of it at a future date.

# If /nas doesn't exist it fails over to / just like we want
pctused_nas=$( df -h /nas | awk 'FNR == 2 {sub(/\%$/,"",$5); print $5}' )
spaceused_nas=$( df /nas | awk 'FNR == 2 {print $3}' )
spaceava_nas=$( df /nas | awk 'FNR == 2 {print $4}' )
partition=$( df /nas | awk 'FNR == 2 {print $NF}' )

size_status "$pctused" "$partition"

if [[ $pctused_nas -gt 75 ]]; then 
	echo -en "\nChecking for autoptimize:"
	for site in $(ls /nas/wp/www/sites)
	do
		if [[ -d "/nas/wp/www/site/$site/wp-content/cache/autoptimize/" ]]; then
			echo -e "Cleaning Production\t$site"
			find "/nas/wp/www/site/$site/wp-content/cache/autoptimize" -regex '.*\.\(js\|css\|img\)$' -mmin +15 -delete
		fi
		if [[ -d "/nas/wp/www/staging/$site/wp-content/cache/autoptimize/" ]]; then
			echo -e "Cleaning Staging\t$site"
			find "/nas/wp/www/staging/$site/wp-content/cache/autoptimize" -regex '.*\.\(js\|css\|img\)$' -mmin +15 -delete
		fi
	done

	echo -e "\n\nChecking .git dirs"
	for site in /nas/wp/www/sites/*
	do 
		site_git="$site/.git"
		if [ -d "$site_git" ]; then
			size=$( du -s "$site_git" | awk '{printf("%d",$1)}' ) 
			if [[ $size -lt $(( 1024 * 1024 )) ]]
			then 
				message=$( success_message "$(( size / 1024 ))MB" )
				echo -e "\t$message\t$site_git"
			else
				message=$( error_message "$(( size / 1024  ))MB" )
				echo -e "\t$message\t$site_git"
				if [[ 0 = "$force" ]] ; then
					if [[ 1 = "$force_no" ]]; then 
						cleanup='n'
					elif [[ $size -gt $spaceava_nas ]]; then
						print_error "ERROR: Not enough disk space to prune git repo"
						echo -e -n "\tSkip gc cleanup\t (y/n): "
						read cleanup_skip
						# If someone uses auto yes, it will autoskip large git's
						if [[ "$cleanup_skip" = "y" ]]; then
							cleanup='n'
						else
							cleanup='y'
						fi
					else 
						echo -e -n "\tDo gc cleanup\t (y/n): "
						read cleanup
					fi
				fi
				if [[ "y" = "$cleanup" ]] || [[ 1 = "$force" ]]
				then	
					while [[ $( ps --no-headers -o pid --ppid=$$ | wc -l ) -gt 3 ]]; do echo "Waiting for process ..." && sleep 2; done
					back=$PWD
					cd "$site_git"
					echo "Cleaning $site_git"
					git config pack.threads 1 
					git config pack.deltaCacheSize 512m 
					git config pack.packSizeLimit 512m 
					git config pack.windowMemory 512m 
					ionice -c2 -n6 nice -n19 git gc --prune=now > /dev/null
					cd "$back"
				fi
			fi
		fi	
	done
fi
	  
if [[ "$skipsitecheck" -lt 1 ]]; then
	echo -e "\n\nChecking Sites/Plans"
	echo -e "Customer\t(Mb)\tChild\tPlan"
	INSTALLS=$(ls -1 /nas/wp/www/sites/ | while read i
	do 
		php /nas/wp/www/tools/wpe.php parent-record-get "$i" | grep -Po '(?<=account_name\]\ \=\>\ )\w+$'
	done | sort | uniq -c | sort -n)
   	
	PLAN=$(echo "$INSTALLS" | while read site
	do
		echo -en "$site\t"; php /nas/wp/www/tools/wpe.php customer-record-get $(echo "$site" | awk '{print $2}') | grep -Po '(?<=\[plan\]\ =>\ )\w+$'
	done)
	
	SPACE=$(for customer in $(echo "$INSTALLS" | awk '{print $2}')
	do
		for site in $(/nas/wp/ec2/cluster parent-child "$customer")
		do
			du -ms /nas/wp/www/{sites,staging}/"$site" 2> /dev/null
		done | awk '{total = total+$1}END{print total}'
	done)

	paste <(echo "$SPACE") <(echo "$INSTALLS") <(echo "$PLAN") | awk -v OFS="\t" '{print $3, $1, $2, $6}' | sort -n -k2

	if [ -d "/etc/wpengine/bin/reaper.py" ]; then
		echo -e "\n\nReaper kill list"
		python /etc/wpengine/bin/reaper.py -dsv
	fi
fi

wait=1
running=$(ps --no-headers -o pid --ppid=$$ | wc -l)
while [ $wait -eq 1 ]
do
	echo "Waiting for $running processes to complete"
	#check again and see whether we should keep waiting
	running=$(ps --no-headers -o pid --ppid=$$ | wc -l)
	if [ "$running" -lt 2 ] ; then
		wait=0
	else
		sleep 2
	fi
done

#Truncating logs can make valuble data disapper, This will this will show up in the log check
#if it becomes a problem.
#echo "Disabling and clearing MySQL general logging"
#mysql -e "SET GLOBAL general_log = 'OFF';"
#>/var/log/mysql/general.log

new_spaceused=$( df / | awk 'FNR == 2 {sub(/\%$/,"",$3); print $3}' )
spacefreed=$(( spaceused - new_spaceused ))
echo "FREED up on / $(( spacefreed / 1024 /1024 )) M"
logger "UTIL:$0 / RESULT:$(( spacefreed / 1024 /1024 )) M"
if df -h /nas | grep --quiet nas; then
	new_spaceused_nas=$( df /nas | awk 'FNR == 2 {sub(/\%$/,"",$3); print $3}' )
	spacefreed=$(( spaceused_nas - new_spaceused_nas ))
fi
echo "FREED up on /nas $(( spacefreed / 1024 /1024 )) M"
logger "UTIL:$0 /nas RESULT:$(( spacefreed / 1024 /1024 )) M"
exit
