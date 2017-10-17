#!/bin/bash

# This script will either enable or disable outbound connection logging to /var/log/syslog
#
# Run this with argument "enable" to turn outbound connection logging on
# Run this with argument "disable" to turn outbound connection logging off

if [ $1 = "enable" ]; then
 iptables -N LOGGER
 iptables -A LOGGER -d 127.0.0.0/8 -j RETURN
 iptables -A LOGGER -d 50.116.62.227 -j RETURN
 iptables -A LOGGER -d 72.14.179.5 -j RETURN
 iptables -A LOGGER -d 72.14.188.5 -j RETURN
 iptables -A LOGGER -d 8.8.8.8 -j RETURN
 iptables -A LOGGER -d 8.8.4.4 -j RETURN
 iptables -A LOGGER -d 216.151.212.35 -j RETURN
 iptables -A LOGGER -d 69.20.11.203 -j RETURN
 iptables -A LOGGER -m state --state NEW -j LOG --log-prefix "new_connection: " --log-level info
 iptables -A OUTPUT -j LOGGER
fi

if [ $1 = "disable" ]; then
 iptables -D OUTPUT -j LOGGER
 iptables -D LOGGER -d 127.0.0.0/8 -j RETURN
 iptables -D LOGGER -d 50.116.62.227 -j RETURN
 iptables -D LOGGER -d 72.14.179.5 -j RETURN
 iptables -D LOGGER -d 72.14.188.5 -j RETURN
 iptables -D LOGGER -d 8.8.8.8 -j RETURN
 iptables -D LOGGER -d 8.8.4.4 -j RETURN
 iptables -D LOGGER -d 216.151.212.35 -j RETURN
 iptables -D LOGGER -d 69.20.11.203 -j RETURN
 iptables -D LOGGER -m state --state NEW -j LOG --log-prefix "new_connection: " --log-level info
 iptables -X LOGGER
fi
