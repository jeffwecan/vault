#!/usr/bin/bash
account=${1:?"Must enter a site"}
func=${2:?"Usage: {start|stop|auto}"}

# If in auto mode mk sure we have a waitime
if [[ $func = "auto" ]]; then waittime=${3:?"Must specify wait time when using auto mode"}; fi

if [ ! -f /etc/wpengine/bin/lib/php/ajax-logger.php ]; then echo "Couldn't find logging script! Die!"; exit 1; fi;

siteroot="/nas/wp/www/sites/$account"

if [[ "$func" = "start" ]] || [[ "$func" = "auto" ]]; then
	cp /etc/wpengine/bin/lib/php/ajax-logger.php "$siteroot/ajax-logger.php"
	touch $siteroot/admin-ajax.log
	chmod 0664 "$siteroot/ajax-logger.php" 
	chmod 0664 "$siteroot/admin-ajax.log"
	chown www-data:www-data "$siteroot/ajax-logger.php" 
	chown www-data:www-data "$siteroot/admin-ajax.log"

	if [ ! -f $siteroot/.htaccess.bk ] 
	then
		cp $siteroot/.htaccess $siteroot/.htaccess.bk
		echo "Backing up .htaccess ..." 
	fi

	echo "Updating .htaccess conf ..." 
	echo "php_value auto_prepend_file $siteroot/ajax-logger.php" >> $siteroot/.htaccess
	
	# only tail if we're not in auto mode
	if [[ "$func" != "auto" ]]; then
		echo "Tailing admin-ajax.log"	
		tail -f $siteroot/admin-ajax.log
	fi

fi

if [[ $func = "auto" ]]; then
	echo "Waiting ${waittime}s for scan"
	sleep ${waittime}s
	func="stop"
	summary="yes"
fi

if [[ "$func" = "stop" ]]; then
	
	if [[ "$summary" = "yes" ]]; then
		while read hook
		do 
			action=$( echo $hook | awk '{print $2}' )
			count=$( echo $hook | awk '{print $1}' )
			while read line
			do
				echo -ne "\t ACTION: $action \t Count: $count \t Source: "
				plugin=$(echo $line | sed -r 's@(^.*)plugins/(.*):([1-9]+)?.*@\2 \tLine\3@g')
				echo -e "$( echo $plugin | awk -F':' '{print $1}') Line:$( echo $plugin | awk -F':' '{print $2}')"
			done < <( grep -rn $action $siteroot/*/plugins )
		done < <( cat $siteroot/admin-ajax.log | sed -r 's@.*action=(.+)[ ].*@\1@' | awk '{print $1}' | sort -n | uniq -c | sort -rn )
	fi

	rm $siteroot/ajax-logger.php
	rm $siteroot/admin-ajax.log
	mv -f $siteroot/.htaccess.bk $siteroot/.htaccess
fi

echo "Restarting apache ..."
service apache2 graceful

