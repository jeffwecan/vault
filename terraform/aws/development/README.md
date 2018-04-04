# development

This Terraform module configures connections and DNS records to allow for requests from privileged Vault clients over private subnets. To this end, the following three [infraform](https://github.com/wpengine/infraform/) modules are leveraged:

- [infraform/modules/aws-vpc-peering-to-vault-vpc](https://github.com/wpengine/infraform/tree/master/modules/aws-vpc-peering-to-vault-vpc)
- [infraform/modules/gcp-vpn-to-vault-vpc](https://github.com/wpengine/infraform/tree/master/modules/dns-for-aws-elbv2)
- [infraform/modules/gcp-vpn-to-vault-vpc](https://github.com/wpengine/infraform/tree/master/modules/dns-for-aws-elbv2)

## aws-vpc-peering-to-vault-vpc
This module is responsible for connecting the AWS subnet used by the development metrics servers (e.g., metricsdb1, metricsapp1, and metricsweb1) within the "corporate core" VPC via VPC peering with the development Vault VPC. Additionally, it configures route tables and security groups to allow Vault clients in the provided subnet to send requests to Vault via HTTPS. It uses its required variables to look up:

- The VPC containing the Vault service/instances
- The route table for the Vault instances
- The subnet of the metrics instances

Route tables are updated for the metrics instances and vault cluster to allow communication via the peered VPC CIDR. A security group rule is added to the vault cluster application load balancer to allow ingress from the metrics instances via HTTPS / port 443.

## gcp-vpn-to-vault-vpc
This module will sets up dev-cm's Google Compute Network for communication to the Vault VPC at AWS via the [GCP VPN / Cloud Interconnect service](https://cloud.google.com/interconnect/) service. Additionally, it configures route tables and security groups to allow dev-cm to send requests to Vault via HTTPS. The VPN configuration bits of this module were mostly derived from [https://github.com/GoogleCloudPlatform/autonetdeploy-multicloudvpn/](https://github.com/GoogleCloudPlatform/autonetdeploy-multicloudvpn/). It performs look ups to populate Terraform data sources for the following resources:

- The VPC containing the Vault service/instances
- The route table for the Vault instances
- The Google Compute Network of the Vault client instance(s)

A VPN connection (ipsec.1) is made between dev-cm at GCP and the Vault cluster VPC's. Two VPN tunnels are created to ensure high-availability. Route tables are updated for the vault cluster to allow communication via the provided dev-cm / GCP network CIDR. A security group rule is added to the Vault cluster application load balancer to allow ingress from the dev-cm via HTTPS / port 443.

aws-vpc-peering-to-vault-vpc


## dns-for-aws-elbv2
This module creates a DNS record for development Vault's internally-facing (i.e., ingress via private subnets only) EC2 Application load balancer. This module expects the ARN of the ELB being referenced to be provided as an input variable. Upon an apply of this terraform module, the `vault-dev.wpesvc.net` DNS record is established.
