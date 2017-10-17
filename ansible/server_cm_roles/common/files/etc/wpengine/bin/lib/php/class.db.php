<?php

class LoadDB {
	static $connection = false;	

	public function __construct($db) {
		$creds = parse_ini_file( "/root/.my.cnf" );
		self::$connection = new PDO('mysql:host=127.0.0.1;dbname=', $creds['user'], $creds['password'] );
		return $this;
	}
	
	static function instance( $db ) 
	{
		if ( empty(self::$connection ) ) 
			new LoadDB( $db );
		return self::$connection;
	}

}
