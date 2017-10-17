#! /bin/bash

# Disable Apache core dumps if the Apache error log indicates that a segmentation
# fault has occurred. The intent is for this script to run in cron with a high
# level of frequency so that the disk doesn't fill up with core files. 

# Only cancel core dumps if core occurred in last $TIMEOUT seconds.
TIMEOUT=600

now=`date '+%s'`
cat /var/log/apache2/error.log | grep Segmentation | while read line
do
    dumpon=$( echo $line | cut -d\] -f 1 | cut -d\[ -f 2 ) 
    dump=$( date --date "$dumpon" "+%s" )
    difference=`expr $now - $dump`
    echo "Segmentation fault occurred $difference seconds ago."
    if (( $difference < $TIMEOUT )); then 
        echo "Modifying Apache configuration..."
        sed -e '/^CoreDumpDirectory/s/^/#/' < /etc/apache2/apache2.conf > /tmp/apache2.conf
        if diff /etc/apache2/apache2.conf /tmp/apache2.conf >/dev/null ; then
            # Files are the same; already disabled.
            echo "Already disabled. Not restarting."
            break
        else
            echo "Restarting Apache..."
            mv /tmp/apache2.conf /etc/apache2/apache2.conf
            service apache2 restart
            break
        fi
    fi
done
 

echo DONE
