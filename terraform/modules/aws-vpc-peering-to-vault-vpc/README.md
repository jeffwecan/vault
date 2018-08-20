# aws-vpc-peering-to-vault-vpc

This Terraform module will take a provided AWS subnet within an existing VPC and peer that VPC with the Vault VPC at AWS.
Additionally, it configures route tables and security groups to allow Vault clients in the provided subnet to send
requests to Vault via HTTPS.

This Module does not currently include an submodules.

## Details

This module expects two AWS providers with the aliases "vault_client" and "vault_cluster" to be passed in. It uses its
required variables to look up:

* The VPC containing the Vault service/instances
* The route table for the Vault instances
* The subnet of the Vault client instance(s)

A VPC peering connection is made between the vault client and vault cluster VPC's. Note: this module currently only
supports VPC peering between VPC's under the same AWS account. E.g., a vault client under the development account can
only connect to the development vault cluster, etc.

Route tables are updated for the vault client *and* vault cluster to allow communication via the peered VPC CIDR. A
security group rule is added to the vault cluster application load balancer to allow ingress from the vault client via
HTTPS / port 443.
