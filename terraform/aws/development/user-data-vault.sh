#!/bin/bash
# This script is meant to be run in the User Data of each EC2 Instance while it's booting. The script uses the
# run-consul script to configure and start Consul in client mode and then the run-vault script to configure and start
# Vault in server mode. Note that this script assumes it's running in an AMI built from the Packer template in
# examples/vault-consul-ami/vault-consul.json.

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

#/usr/local/bin/supervisorctl start consul-agent
#/usr/local/bin/supervisorctl start vault
echo /usr/bin/ansible-playbook -c local -i localhost, \
	"${vault_bootstrap_playbook}" \
	-vvv \
	--tags bootstrap \
	--extra-vars "@${vault_bootstrap_vars}"

sudo HOME=/root /usr/bin/ansible-playbook -c local -i localhost, \
	"${vault_bootstrap_playbook}" \
	-vvv \
	--tags bootstrap \
	--extra-vars "@${vault_bootstrap_vars}"
