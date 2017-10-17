total=0 ; 
for i in `ps -C apache2 -o rss=`; do 
	total=$(($total + $i));
done; 

bresp="0.0"
count=0
bcount=0
while read line; do
	rtime=$( echo $line | cut -d'|' -f8 )
	if [[ $rtime != "-" ]]; then
		bresp=$( echo "$bresp + $rtime" | bc )
		bcount=$(( $bcount + 1 ))
	fi
	count=$(( $count + 1 ))
done < <( egrep "^$( date +%d/%b/%Y:%H -d "1 hour ago")" /var/log/nginx/*.access.log )
brespavg=$( printf "%.3f" $( echo "$bresp / $bcount" | bc -l  ) )
bhits=$( egrep "$( date +%d/%b/%Y:%H -d "1 hour ago")" /var/log/apache2/*.access.log | wc -l )
bratio=$( printf "%.3f" $( echo "$bhits / $count" | bc -l ) )
echo "POD=$( cat /etc/cluster-id ) MEMORY=$(( $total / 1024 ))mb BTIME=$bresp BAVG=$brespavg BRATIO=$bratio BHITS=$bhits"
