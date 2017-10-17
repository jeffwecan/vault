<?php
// have to do some prep work. This makes sure ingrep is available and there is some output to read
system('apt-get install -y ngrep > /dev/null && pear install Console_Table > /dev/null; > /tmp/ngrep; ngrep -W single -q "^POST" tcp and port 80 >> /tmp/ngrep &');
system( 'sleep 10 && pkill -9 ngrep' );

require_once 'Console/Table.php';
class AjaxView {
        public $shortopts = "a::f::";
        public $longopts = array(
                'account::',
                'field::',
        );
        public $account;
        public $data;

        public function __construct($argv)
        {
		$tempfile = "/tmp/ngrep";
		$ngrep = fopen($tempfile,"r");
		$analysis = array();
		while ( false !== ( $line = fgets( $ngrep) ) ) {
			$index = stripos($line, "POST");
			$source = substr( $line, 0, $index );
			$data = substr( $line, $index);
			$data = explode( "....", $data );	
			$headers = $data[0];
			$body = @$data[1];
			$headers = explode( "..", $headers );
			$host = "";
			foreach( $headers as $header ) {
				$header=explode(":",$header);
				if( "Host" == $header[0] ) {
					$host = $header[1];
				} 
				@$analysis['headers'][$header[0]][$header[1]] += 1;
			}
			if( $body ) {
				parse_str( $body , $args);
				foreach($args as $k=>$v) {
					@$analysis['args'][$k] +=1;
					if ( $k == "action" ) {
						@$analysis['actions'][$v]['count'] += 1;
						@$analysis['actions'][$v]['domains'][] = $host;
					}
				}	
			}
		}
		$this->data = @$analysis;
	}

	function sortIndex($index) 
	{
		uasort( $this->data[$index], function($a,$b) { 
			if( $a['count'] == $b['count'] ) return 0; 
			return ( $a['count'] > $b['count'] ) ? 1 : 0;
		});
	}

	function actions() 
	{
		if( empty($this->data['actions']) ) { 
			echo "No data".PHP_EOL;
			return false;
		}
	
		$this->sortIndex('actions');
		$table = new Console_Table();
		$table->setHeaders( array("Action","Count","Host","Account","Source") );
		foreach( $this->data['actions'] as $key => $action ) {
			if( "" == $key ) continue;
			$this->findit = true;
			$hosts= join(",",array_unique($action['domains']));
			if( $this->findit === true ) {
				$host = substr( $hosts , 0 , stripos($hosts,',') );
				if( !$host ) { $host=$hosts; }
				$host = trim($host);
				$account = shell_exec( 'cd /nas/wp/conf/lb/sites; grep -r '.escapeshellarg($host).' . | sed -r \'s@^\\./([^\./]+)\\.conf\\:.*@\\1@\' | uniq');
				$srcdir = "/nas/wp/www/sites/".trim($account);
				$cmd =  sprintf( "grep --include=*.php  -r %s %s | sed -r 's@%s(.*):.*@\\1@' | uniq ", $key, "$srcdir/wp-content/plugins" , "$srcdir/wp-content/plugins" );
				$greps = shell_exec($cmd);
				
			}
			$table->addRow( array( $key, trim($action['count']), $hosts, trim($account), substr($greps,0,50) )  );
		}
		echo $table->getTable();	
		return true;
	}

}

$ajax = new AjaxView($argv);
$ajax->actions();
