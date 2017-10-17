#!/bin/bash

function=${1:?"must specify function"}

function find_options {
	dbs=$(if test $1 ; then echo $1; else mysql -Bse "show databases" | grep -v "snapshot_"; fi)
	for db in $dbs
	do
		for table in $( mysql -Bse "use $db; show tables LIKE '%options'" )
		do
			echo "$db.$table"
		done
	done
}

function finish {
	mysql -e "set global log_output='FILE' ; set global general_log = 0; TRUNCATE mysql.general_log;"	
	echo "Cleaning Up"
}

case "$function" in
	check-creds)  echo "checking for creds"
			user=$( bash /etc/wpengine/bin/cfg.sh mysql_replication user )
			echo "user:$user"
			pass=$( bash /etc/wpengine/bin/cfg.sh mysql_replication pass )
			echo "pass:$pass"
		;;
	repair-slave) echo "forcing slave sync"
			echo -n "Enter valid slave to copy from: "
			read slave
			check=$(ssh $slave "mysql -Bse 'show slave status \G;' | grep 'Seconds_Behind'" | awk '{print $2}')
			if [[ "0" != $check ]]; then
				echo "It appears the source slave is not in sync! [RETURNED:$check]"
				exit 1
			fi
			echo -e "stopping mysql ..."
				mysql -e "stop slave" && service mysql stop
			echo -e "initial rsync of files ..."
				rsync --progress -Saz $slave:/var/lib/mysql/ /var/lib/mysql/ --exclude='ib_logfile*' --exclude=auto.cnf --delete
				rsync --progress -Sazv $slave:/var/log/mysql/ /var/log/mysql/ --delete
			echo -e "stopping source slave"
				ssh $slave "mysql -e 'stop slave'" 
			echo -e "rsyncing files ..."
				rsync --progress -Saz $slave:/var/lib/mysql/ /var/lib/mysql/ --exclude=auto.cnf
				rsync --progress -Sazv $slave:/var/log/mysql/ /var/log/mysql/
			echo -e "restarting source ..." 
				ssh $slave "mysql -e 'start slave'"
			echo -e "cleaning slave ... "
				mv /var/lib/mysql/master.info /var/lib/mysql/master.info.script
				mv /var/lib/mysql/relay-log.info /var/lib/mysql/relay-log.info.script
			logfile=$( sed -n 1p /var/lib/mysql/relay-log.info.script )
			logposition=$( sed -n 2p /var/lib/mysql/relay-log.info.script )
			mysqlbinlog --start-position=$logposition  $logfile | mysql
			masterbin=$( sed -n 2p /var/lib/mysql/master.info.script )
			masterlog=$( sed -n 3p /var/lib/mysql/master.info.script )
			cluster=$( cat /etc/cluster-id )
			echo -e "starting mysql ... "
				service mysql start --skip-slave-start
			user=$( bash /etc/wpengine/bin/cfg.sh mysql_replication user )
			pass=$( bash /etc/wpengine/bin/cfg.sh mysql_replication pass )
			mysql -e "CHANGE MASTER TO MASTER_HOST='dbmaster-$cluster', MASTER_USER='$user', MASTER_PASSWORD='$pass', MASTER_LOG_FILE='$masterbin', MASTER_LOG_POS=$masterlog"
			mysql -e "start slave"
		;;
	autoload) echo "fixing autoload options"
			for table in $( find_options )
			do
				fix=${2:-"no"}
				account=${3:-"NULL"}
				count=$( mysql -Bse "select count( option_id ) from $table where autoload = 'yes'" 2>/dev/null)
				if [[ $fix = "yes" ]]; then
					if [[ $account != "NULL" ]] && [[ $table != $account ]]; then continue; fi;
					if [[ $count -lt 1 ]]; then
						mysql -Bse "update $table set autoload = 'yes' where option_name IN('home','siteurl');"
					else
						opts=0
						for option in $( mysql -Bse "select o.option_id from $table o INNER JOIN ( select option_id, length(option_value) as len from $table  where autoload = 'yes') o2 ON o2.option_id = o.option_id where o2.len > 1000" 2>/dev/null )
						do
							mysql -Bse "update $table set autoload = 'no' where option_id = $option;"	
							opts=$((opts + 1))
						done
						if [ "$?" -eq 0 ]; then echo -e "\tFixed $table : $opts"; fi
						count=$( mysql -Bse "select count( option_id ) from $table" )
					fi
				fi
				echo "$count $table" 
			done 
		;;
	longopts) echo "looking for long options ... "
			echo -e "LENGTH\tNAME\t\t\t\tTABLE"
			for table in $( find_options )
			do
				mysql -Bse "select option_name,length(option_value) as len from $table order by len desc limit 10" 2>/dev/null | awk -v "table=$table" '{gsub(/[ \t]+$/, "", table); print $2 "\t" substr( $1, 0, 25) "\t\t\t\t" table}'
			done | sort -rn | head -n 20
		;;
	repair) echo "running myisam check and repair ..."
			dir=$( pwd )
			cd /var/lib/mysql && find . -name "*.MYI" -exec myisamchk -r {} \;
			cd $dir
		;;
	countopts) echo "counting options ..." 
			for table in $( find_options )
			do
				found=$( mysql -Bse "select count(option_id) from $table" 2>/dev/null )
				echo "$found $table" 
			done | sort -rn | head 
		;;
	sessions) echo "finding expired sessions ..."
			total=0 
			for table in $( find_options $2 )
			do
				echo -e "\t $table ..."
				count=0
				while read line
				do
					date=$( echo $line | awk '{print $2}' )
					current=$( date +"%s" )
					if (( $date < $current ))
					then 
						expires_name=$( echo $line | awk '{print $1}')
						echo -n "Found Expired Session ... $expires_name"
						echo "$( date -d @$date ) is older than current time: $( date -d @$current )"
						session_name=$( echo $line | awk '{print $1}' | sed -r 's/_(.*)_session_expires_(.*)/_\1_session_\2/g' )
						mysql -Bse "delete from $table where option_name IN( '$sesssion_name','$expires_name' ) ;"
						count=$(( $count + 1 )); 
 					fi
				done < <( mysql -Bse "select option_name,option_value from $table where option_name LIKE '_%_session_expires_%'" )
				
				total=$(( $total + $count ))
			done
			echo "TOTAL SESSIONS DELETED: $total"
		;;		
	transients) echo "finding expired transients ..." 
			total=0
			for table in $( find_options $2 )
			do
				echo -e "\t $table ..."
				count=0
				while read line
				do
					date=$( echo $line | awk '{print $2}' )
					current=$( date +"%s" )
					if (( $date < $current ))
					then 
						expires_name=$( echo $line | awk '{print $1}')
						echo -n "Found Expired Session ... $expires_name"
						echo "$( date -d @$date ) is older than current time: $( date -d @$current )"
						transient_name=$( echo $line | awk '{print $1}' | sed -r 's/(.*)_timeout(.*)/\1\2/g' )
						echo $session_name
						mysql -Bse "delete from $table where option_name IN( '$transient_name','$expires_name' ) ;"
						count=$(( $count + 1 )); 
 					fi
				done < <( mysql -Bse "select option_name,option_value from $table where option_name LIKE '%transient_timeout%'" )

				echo "Finding large transients that bloat the DB ... "
				while read line
				do
					transient_name=$( echo $line | awk '{print $1}' | sed -r 's/_transient_(.*)/\1/g' )
					length=$(mysql -Bse "select LENGTH(option_value) from $table where option_name = '_transient_$transient_name'")
					if [[ $length -gt 100000 ]]; then
						echo "Deleting $transient_name  : $length"; 
						mysql -Bse "delete from $table where option_name = '_transient_$transient_name'"
						count=$(( $count + 1 ));
					fi
				done < <( mysql -Bse "select option_name,option_value from $table where option_name LIKE '%_transient_%'" ) 	
				total=$(( $total + $count ))
			done
			echo "TOTAL TRANSIENTS DELETED $total"
		;;		
	cron) echo "checking crons ..."
			for table in $( find_options ) 
			do 
				found=$( mysql -Bse "select length(option_value) as len from $table where option_name = 'cron'" 2>/dev/null ) 
				echo "$found $table"
			done | sort -rn
		;;
	cronfixer) echo "running cronfixer"
			if [[ $2 = "yes" ]]
			then echo "fixing"
				php /etc/wpengine/bin/lib/php/class.cronfixer.php fix_all
			else
				php /etc/wpengine/bin/lib/php/class.cronfixer.php analyze_all
			fi
		;;
	watch) echo "Watching: $2" 			
			trap control_c SIGINT
			mysql -e "set global log_output='TABLE' ; set global general_log = 1"
			while read line
			do 
				line=$( echo $line | sed -r 's/\@ localhost \[127\.0\.0\.1\]//' )
				echo $line | awk '{ printf "%-40s %-20s\n", $1, $2 }' 
			done < <( mysql -Bse "select user_host,count(user_host) as count from mysql.general_log where event_time < NOW() and event_time > DATE_SUB( NOW(), INTERVAL 1 MINUTE) GROUP BY user_host ORDER BY count desc LIMIT 10" )
		;;
	cleanup) echo "Cleanup" 
		finish
		;;

	log-summary)	lines=${2:-10000}
			echo "Summarizing general log [ $lines lines ]"
			tail -n $lines /var/log/mysql/general.log | sed -r 's@.*\[([^\]+)\]\s\*/$@\1@' | grep "^/nas/wp.*" | sort | uniq -c | sort -rn 	
		;;
	delete-option) echo "Deleting option $2" 
		option=${2:?"please specify an option to delete"}
		for table in $(find_options)
		do
			mysql -e "delete from $table where option_name = '$option'"
		done
		;;
esac

