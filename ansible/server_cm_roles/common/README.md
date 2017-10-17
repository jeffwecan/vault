common
======

Common tasks that should be run on every host.

Pollers and Cron Jobs
---------------------

Pollers are long running commands that process data.  Cron jobs are short processes that run at a given interval.

Role Variables
--------------

	pollers:
	    - { name: my-poller, user: "pollers", command: "ping google.com" }

	cron_jobs:
	    - name: "Ping Google"
	      minute: "0"
	      hour: "5"
	      job: "ping google.com"
    	- name: "Ping Yahoo"
    	  state: "absent"

Logs
-----

* [Gophpr fluentd logs](../../docs/td-agent/README-gophpr.md)