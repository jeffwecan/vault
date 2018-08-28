variable "aws_corporate_role_arn" {
  type        = "string"
  description = "AWS role ARN to assume when modifying DNS zones under the corporate account."
  default     = "arn:aws:iam::770273818880:role/wpengine/robots/TerraformApplier"
}

variable "aws_corporate_dns_role_arn" {
  type        = "string"
  description = "AWS role ARN to assume when modifying DNS zones under the corporate account."
  default     = "arn:aws:iam::770273818880:role/wpengine/administrators/WPEngineIoRoute53AdminPolicy"
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
  default     = "vault"
}

variable "peer_owner_id" {
  type        = "string"
  description = "Account ID of the AWS account housing the VPC peering connection."
  default     = "770273818880"
}

variable "corporate_core_cf_stack_name" {
  type        = "string"
  description = "Name of the CloudFormation stack holding related corporate_core resources."
  default     = "CorpCore"
}

variable "cm_subnet_ids" {
  type        = "list"
  description = "Subnet ID(s) for the cm-aws instance"
  default     = ["subnet-2273fc1f"]
}

variable "jenkins_subnet_ids" {
  type        = "list"
  description = "Subnet ID(s) for the Jenkins master instance"
  default     = ["subnet-e975a9c4"]
}

variable "zabbix_subnet_ids" {
  type        = "list"
  description = "Subnet ID(s) for the zabbix 'main' instance in the 'Zabbix' VPC."
  default     = ["subnet-eba99e9d"]
}

// The following three variables' values can be determined via heroku-cli and `heroku spaces:peering:info <space_name>`
variable "heroku_wpengine_corporate_space_peer_owner" {
  type        = "string"
  description = "The VPC ID of our 'wpengine-corporate' space in Heroku. See: https://devcenter.heroku.com/articles/private-space-peering#creating-a-peering-connection-to-your-private-space"
  default     = "505048354400"
}

variable "heroku_wpengine_corporate_space_vpc_id" {
  type        = "string"
  description = "The VPC ID of our 'wpengine-corporate' space in Heroku"
  default     = "vpc-5cf5e127"
}

variable "heroku_wpengine_corporate_space_dyno_cidrs" {
  type        = "list"
  description = "The VPC ID of our 'wpengine-corporate' space in Heroku"
  default     = ["10.0.128.0/20", "10.0.144.0/20"]
}

variable "dns_private_corporate_zone" {
  description = "Domain/zone to use for any DNS records needed on a 'corporate core-related' private route53 zone."
  type        = "string"
  default     = "corporate.private."
}

variable "instance_ssh_key_name" {
  type        = "string"
  description = "Name of the AWS EC2-hosted SSH public key to grant SSH access to for the instance."
  default     = "cm_provisioning"
}

variable "instance_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for EC2 instances."
  default     = "wpengine.io"
}

variable "service_dns_zone" {
  type        = "string"
  description = "DNS zone to use when creating records for services / load balancers."
  default     = "wpesvc.net"
}
