<?php
require_once 'Console/Table.php';
class QueueView {
	public $shortopts = "a::f::";
	public $longopts = array( 
		'account::',
		'field::',
	);
	public $account;
	public $data;
	
	public function __construct($argv) 
	{
		$this->loaddata();
		$args = getopt( $this->shortopts, $this->longopts ); 
		if ( array_key_exists( 'account', $args ) ) {
			$this->account = $args['account'];
			print "Looking up ".$this->account.PHP_EOL;
			if( $this->account == 'all' ) {
				$this->all();
			} else {
				$this->one();
			}
		}
	}

	public function all( $args = array() )
	{
		$tbl = new Console_Table();
		$tbl->setHeaders( array("Bucket","Weight","Active","Total","Queued","Running","Backlog","Evictions","Avg/Process","Avg/Wait") );
		foreach( $this->data['sites'] as $bucket ) {
			$tbl->addRow(array(
				$bucket['bucket_name'],
				$bucket['weight'],
				$bucket['active_requests'],
				$bucket['total_requests'],
				$bucket['queued_requests'],
				$bucket['running_requests'],	
				$bucket['backlog_requests'],
				$bucket['evictions'],
				$bucket['average_time_to_process'],
				$bucket['average_time_in_queue'],
			));
		}
		echo $tbl->getTable();
	}

	public function one() 
	{
		foreach( $this->data['sites'] as $bucket ) {
			if( @$bucket['bucket_name'] != $this->account ) continue;	
			$tbl = new Console_Table();
			$tbl->setHeaders( array("Key","Value") );
			foreach( $bucket as $key => $value ) {
				if( is_array( $value ) ) {
					$tbl->addRow( array( $key, " ")  );
					foreach( $value as $k => $v ) {
						$tbl->addRow( array( " -$k", (string) $v ?:"-" ) );
					}
				} else {
					$tbl->addRow(array($key, (string) $value ?: "-" ));
				}
			}
			echo $tbl->getTable();
		}
	}

	public function loaddata() 
	{
		$ch = curl_init("localhost/proxyprint");
		curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
		$resp = curl_exec($ch);
		$resp = json_decode( $resp, 1);
		$this->data = $resp;
	}
}

new QueueView( $argv );

