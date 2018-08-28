variable "aws_development_role_arn" {
  type        = "string"
  description = "AWS role ARN to assume when doing deployments of resources under the development account."
  default     = "arn:aws:iam::844484402121:role/wpengine/robots/TerraformApplier"
}

variable "aws_corporate_dns_role_arn" {
  type        = "string"
  description = "AWS role ARN to assume when modifying DNS zones under the corporate account."
  default     = "arn:aws:iam::770273818880:role/wpengine/administrators/WPEngineIoRoute53AdminPolicy"
}

variable "aws_development_region" {
  type        = "string"
  description = "The AWS region hosting the vault clients and servers under the development account."
  default     = "us-east-1"
}

variable "aws_corporate_region" {
  type        = "string"
  description = "The AWS region to use when setting up the corporate account provider."
  default     = "us-east-1"
}

variable "vault_cf_stack_name" {
  type        = "string"
  description = "Name of the CloudFormation stack holding related Vault cluster resources."
  default     = "vault"
}

variable "vault_dns_record_name" {
  type        = "string"
  description = "The record to create on the wpesvc.net to point at Vault's internally facing Application Load Balancer."
  default     = "vault-dev"
}

variable "peer_owner_id" {
  type        = "string"
  description = "Account ID of the AWS account housing the VPC peering connection."
  default     = "844484402121"
}

variable "corporate_core_cf_stack_name" {
  type        = "string"
  description = "Name of the CloudFormation stack holding related corporate_core resources."
  default     = "corp-dev"
}

variable "zabbix_subnet_ids" {
  type        = "list"
  description = "Subnet ID(s) for the zabbix 'main' instance in the 'Zabbix' VPC."
  default     = ["subnet-3fe7c015"]
}

variable "gcp_project" {
  type        = "string"
  description = "The GCP project to connect to for dev-cm."
  default     = "wp-engine-development"
}

variable "gcp_region" {
  type        = "string"
  description = "The GCP region to connect to for dev-cm."
  default     = "us-east1"
}

variable "gcp_network_name" {
  type        = "string"
  description = "The GCP network to reference when establishing the VPN connection for dev-cm."
  default     = "default"
}

variable "dev_cm_subnet_cidr" {
  type        = "string"
  description = "The GCP subnet to route to Vault for dev-cm."
  default     = "10.142.0.0/20"
}

variable "dns_private_corporate_zone" {
  description = "Domain/zone to use for any DNS records needed on a 'corporate core-related' private route53 zone."
  type        = "string"
  default     = "corporate.private."
}

variable "instance_ssh_key_name" {
  type        = "string"
  description = "Name of the AWS EC2-hosted SSH public key to grant SSH access to for the instance."
  default     = "dev-cm"
}

variable "instance_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for EC2 instances."
  default     = "wpenginedev.com"
}

variable "service_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for services / load balancers."
  default     = "wpesvcdev.net"
}
