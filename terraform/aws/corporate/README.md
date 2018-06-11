# corporate

This Terraform module configures connections and DNS records to allow for requests from privileged Vault clients over
 private subnets. To this end, the following three [infraform](https://github.com/wpengine/infraform/) modules are leveraged:

- [infraform/modules/aws-vpc-peering-to-vault-vpc](https://github.com/wpengine/infraform/tree/master/modules/aws-vpc-peering-to-vault-vpc)
- [infraform/modules/gcp-vpn-to-vault-vpc](https://github.com/wpengine/infraform/tree/master/modules/dns-for-aws-elbv2)

An explicit VPC peering connection, route table entries, and security group update are also managed to allow our "wpengine-corporate"
Heroku private space to reach the internally-facing Vault ALB.

## aws-vpc-peering-to-vault-vpc

This module is responsible for connecting the AWS subnet used by the metrics servers
 (e.g., metricsdb1, metricsapp1, and metricsweb1) within the "corporate core" VPC, cm, and Jenkins via VPC peering with the
  Vault VPC. Additionally, it configures route tables and security groups to allow Vault clients in the provided subnet
  to send requests to Vault via HTTPS. It uses its required variables to look up:

- The VPC containing the Vault service/instances
- The route table for the Vault instances
- The subnet of the vault client instances

Route tables are updated for the metrics instances and vault cluster to allow communication via the peered VPC CIDR.
 A security group rule is added to the vault cluster application load balancer to allow ingress from the vault client
 instances via HTTPS / port 443.

## dns-for-aws-elbv2

This module creates a DNS record for development Vault's internally-facing (i.e., ingress via private subnets only) EC2
 Application load balancer. This module expects the ARN of the ELB being referenced to be provided as an input
  variable. Upon an apply of this terraform module, the `vault.wpesvc.net` DNS record is established.
