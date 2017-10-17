<?php
namespace WPE;
/** 
 WPE\Log\AdminAjax.php 
 -Logs incoming admin-ajax.php requests to /var/log/admin-ajax.log
**/
class AdminAjax {
	static $instance;	
	public $logfile = "admin-ajax.log";
	public $path;

	public function __construct() {
		$this->logfile = dirname(__FILE__).'/admin-ajax.log';
		if( $this->qualifyRequest() ) 
			$this->logRequest();	
	}

	public static function instance() {
		if( ! self::$instance instanceof WPE\AdminAjax ) 
			self::$instance = new AdminAjax();

		return self::$instance;
	}

	private function qualifyRequest() {
		$path = $_SERVER['REQUEST_URI'];
		$path = explode( "/", $path );
		if( !$path ) return false;
		$path = array_filter($path);
		$path = end($path);
		if ( strlen($path) < 1 OR !preg_match("#(admin-ajax|xmlrpc)\.php#i", $path ) )
			return false; 
		$this->path = $path;
		return true; 
	}

	private function logRequest() {
		$line = "";
		foreach( $_POST as $k=>$v ) {
			if( is_array($v) ) $v = json_encode($v);
			$line .= "$k=$v ";
		}
		$this->writeToLog( $_SERVER['REQUEST_METHOD'].":".$this->path." ".$line);
	}

	private function writeToLog( $content ) {
		file_put_contents( $this->logfile, $content.PHP_EOL, FILE_APPEND );
	}
}

AdminAjax::instance();
