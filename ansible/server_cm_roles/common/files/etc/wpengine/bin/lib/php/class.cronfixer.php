<?php
require_once __DIR__.'/class.db.php';

class CronFixer {
	public $db;
	public $dbname;
	public $table;
	public $cron_to_fix;
	public $cron;
	public $account;
	public $do_fix = false;
	public $never_fix = array( 
		'scheduled_subscription_end_of_prepaid_term', 
		'scheduled_subscription_payment',
		'wp_publish_future_post', 
		'publish_future_post',
		'wp_scheduled_auto_draft_delete',
		'wp_maybe_auto_update',
		'wp_scheduled_delete',
		'wp_version_check',
	);
	public $verbose = true;

	public function __construct($table, $cron) 
	{
		$table = explode(".", $table);
		$this->hydrate( @$table[0], @$table[1] );
		$this->cron_to_fix = @$cron;
	}

	public function fix() 
	{
		$count = 0;
		if( $this->cron ) {
			$cron = unserialize($this->cron);
			foreach( $cron as $time => $c ) {
				if( $time == "version" ) continue;
				if( $time < time() ) {
					$dt = new DateTime();
					$dt->setTimestamp( $time);
					echo "\t[REASON]:Too old ".$this->cron_to_fix." ".$dt->format('Y-m-d h:i:s').PHP_EOL;
					unset($cron[$time][$this->cron_to_fix]);
				} else {
					// The goal here is to leave the very next instance in place but remove all others. 
					if( $count > 1 ) { 
						unset($cron[$time][$this->cron_to_fix]);
					}
					$count++;
				}
			}	
			foreach( $cron as $time => $c ) {
				if( empty($cron[$time]) ) {
					unset($cron[$time]);
				}
		    	}
			$cron = serialize($cron);		
			$result = $this->db->query( sprintf( "UPDATE %s set option_value = '$cron' WHERE option_name = 'cron'", "{$this->dbname}.{$this->table}" ) );
		}
	}

	/**
	 * Run CronFixer::analyze() on all DBs
	 *
	**/
	public function analyze_all() 
	{	
		$databases = $this->db->query("SHOW DATABASES");
		while( $database = $databases->fetch() ) {
			$dbname = $database['Database'];
			if( !preg_match( "#wp_.*#s", $dbname) ) continue;
			$tables = $this->db->query("SHOW TABLES from $dbname LIKE '%options'" );
			while( $table = $tables->fetch() ) {
				$this->hydrate( $dbname, $table[0] )->analyze();
			}
		}
	}

	public function analyze() 
	{
		$analysis = array();
		if( !$this->cron ) return false;
		$cron_length = strlen( $this->cron ); 
		$crondata = unserialize($this->cron);
		if( !is_array($crondata) ) return false;
		$iterate = new ArrayIterator( $crondata );
		while( $iterate->valid() ) {
			if( $iterate->key() !== 'version' ) {
				$moredata = new ArrayIterator( $iterate->current() );
				while( $moredata->valid() ) {
					if( !array_key_exists( $moredata->key() , $analysis ) ) {
						$analysis[$moredata->key()] = array( 
							'count' 	=> 1,
							'interval_avg'	=> 1,
							'all_intervals'	=> array(),
						
						);
					} else {
						$analysis[$moredata->key()]['count'] += 1;
						$last = new DateTime();
						$last->setTimestamp($analysis[$moredata->key()]['last_interval']);
						$current = new DateTime();
						$current->setTimestamp( $iterate->key() );
						$interval = date_diff( $last, $current);
						$analysis[$moredata->key()]['all_intervals'][] = $interval->format("%s");
						$analysis[$moredata->key()]['all_times'][] = $current;
						$analysis[$moredata->key()]['interval_avg'] = $interval->format("%s") ;
					}
					$analysis[$moredata->key()]['last_interval'] = $iterate->key();
					$moredata->next();
				}
			}
			$iterate->next();
		}
		uasort($analysis, function( $a, $b ) { 
			if( $a['count'] == $b['count'] ) return 0;
			return $a['count'] < $b['count'] ? 1 : 0;
		});
		$hooks_to_return = array();
		foreach( $analysis as $hook => $data ) {
			if( $data['count'] < 10 ) { 
				unset($analysis[$hook]);
				continue;
			}

			// never fix these
			if( in_array( $hook, array('wp_publish_future','woocommerce' ) ) ) {
				unset( $analysis[$hook] );
				continue;
			}
		
			$analysis[$hook]['interval_avg'] = $interval_avg  = array_sum( $data['all_intervals'] ) / $data['count'];

			// if intervals are greater than one day then they probably are ok
			if( $interval_avg > ( 60 * 60 * 24 ) AND $data['count'] < 20 ) {
				unset( $analysis[$hook] );
				continue;
			}
		}

		if( $this->verbose ) {
			echo sprintf( "\tFound %d suspicious cron jobs for %s {LENGTH %d} {%s}", count( $analysis ), $this->account,$cron_length, $this->table).PHP_EOL;
		}

		if( !empty( $analysis ) ) {
			foreach( $analysis as $hook => $data ) {
				$this->cron_to_fix = $hook;
				echo sprintf( "\tJob %s: found %d instances with an average interval of %d secs", $hook, @$data['count'], @$data['interval_avg'] ).PHP_EOL;
				if( $this->do_fix AND !in_array( $this->cron_to_fix, $this->never_fix ) )  {
					$this->fix();
				}
			}
		}
		return $analysis;
	}

	public function hydrate( $db, $table ) 
	{
		$this->account = str_replace( "wp_","",$db );
		$this->table = $table;
		$this->dbname = $db;
		$this->db = LoadDB::instance( $this->dbname ?: 'mysql');
		if( !is_null( $this->table ) ) {
			$crons = $this->db->query( sprintf( "SELECT option_value FROM %s.%s WHERE option_name = 'cron'", $db, $this->table ) );
			if( @$crons AND $crons->rowCount() > 0 ) { 
				$tcrons = $crons->fetchAll();
				$this->cron = @$tcrons[0]['option_value'];
			}
		} else {
			$this->cron = false;
		}
		return $this;
	}

	public function fix_all() 
	{
		$this->do_fix = true;
		$this->analyze_all();
	}
}

if( !empty( $argv ) ) {
	array_shift( $argv );
	$method = array_shift( $argv );
	$cronfix = new CronFixer( @$argv[0], @$argv[1] );
	if ( method_exists( $cronfix, $method ) ) {
		call_user_func_array( array( $cronfix, $method ), array() );
	}
}
