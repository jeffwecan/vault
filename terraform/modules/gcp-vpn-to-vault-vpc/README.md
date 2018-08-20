# gcp-vpn-to-vault-vpc

This Terraform module will take a provided Google Compute Network connect that network with the Vault VPC at AWS via the [GCP VPN / Cloud Interconnect service](https://cloud.google.com/interconnect/). Additionally, it configures route tables and security groups to allow Vault clients in the provided GCP subnet to send requests to Vault via HTTPS. The VPN configuration bits of this module were mostly derived from [https://github.com/GoogleCloudPlatform/autonetdeploy-multicloudvpn/](https://github.com/GoogleCloudPlatform/autonetdeploy-multicloudvpn/).

This Module does not currently include an submodules.

## Details

This module expects an AWS provider with the alias "vault_cluster" and a Google provider with the alias "vault_client" to be passed in. It uses its required variables to look up:
* The VPC containing the Vault service/instances
* The route table for the Vault instances
* The Google Compute Network of the Vault client instance(s)

A VPN connection (ipsec.1) is made between the vault client at GCP and vault cluster VPC's. Two VPN tunnels are created to ensure high-availability. Route tables are updated for the vault cluster to allow communication via the provided GCP network CIDR. A security group rule is added to the vault cluster application load balancer to allow ingress from the vault client via HTTPS / port 443.
