# vault-bastion

This Terraform module will take a provided map of CloudFormation outputs from a Vault cluster stack and insert bastion
instance(s) into the stack's VPC. Additionally, it configures route tables and security groups to allow HTTPS access for
the bastion instances to send requests to Vault via HTTPS.

This module leverages [corpraform's corporate_ec2_instance module](https://github.com/wpengine/corpraform/tree/master/terraform/modules/corporate_ec2_instance).

## Details

This module expects two AWS providers with the aliases "bastion" and "dns" to be passed in. It uses its
required variables construct the following resources:

* Security group and instance role for all Vault bastion instances to use.
* EC2 instance(s) (currently only one) to serve as a bastion into the Vault cluster's UI.
* A "service" DNS record mapped to the bastion instance's public IP address. E.g., `vault-bastion.wpesvc.net`
