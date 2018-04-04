variable "aws_development_role_arn" {
  type = "string"
  description = "AWS role ARN to assume when doing deployments of resources under the development account."
  default = "arn:aws:iam::844484402121:role/wpengine/robots/TerraformApplier"
}

variable "aws_corporate_role_arn" {
  type = "string"
  description = "AWS role ARN to assume when modifying DNS zones under the corporate account."
  default = "arn:aws:iam::770273818880:role/wpengine/robots/TerraformApplier"
}

variable "aws_development_region" {
  type = "string"
  description = "The AWS region hosting the vault clients and servers under the development account."
  default = "us-east-1"
}

variable "aws_corporate_region" {
  type = "string"
  description = "The AWS region to use when setting up the corporate account provider."
  default = "us-east-1"
}

variable "vault_load_balancer_arn" {
  type = "string"
  description = "The Amazon Resource Name (ARN) for the internally-facing Application Load Balancer for Vault nodes."
  default = "arn:aws:elasticloadbalancing:us-east-1:844484402121:loadbalancer/app/vault-Appli-1QA7PEJIOGJ56/d6010dd693eec4be"
}

variable "vault_vpc_id" {
  type = "string"
  description = "The VPC ID for the VPC that contains the vault nodes."
  default = "vpc-6b1fa213"
}

variable "vault_route_table_id" {
  type = "string"
  description = "The VPC route table ID for vault nodes."
  default = "rtb-839cc1f9"
}

variable "vault_load_balancer_security_group_id" {
  type = "string"
  description = "The VPC security group ID for the Vault node load balancer."
  default = "sg-1b8c8569"
}

variable "corporate_core_metrics_subnet_id" {
  type = "string"
  description = "Subnet ID for the metris* instances in the 'CorporateCore' VPC."
  default     = "subnet-88f28fd0"
}

variable "peer_owner_id" {
  type = "string"
  description = "Account ID of the AWS account housing the VPC peering connection."
  default     = "844484402121"
}

variable "gcp_project" {
  type = "string"
  description = "The GCP project to connect to for dev-cm."
  default     = "wp-engine-development"
}

variable "gcp_region" {
  type = "string"
  description = "The GCP region to connect to for dev-cm."
  default     = "us-east1"
}

variable "gcp_network_name" {
  type = "string"
  description = "The GCP network to reference when establishing the VPN connection for dev-cm."
  default     = "default"
}

variable "dev_cm_subnet_cidr" {
  type = "string"
  description = "The GCP subnet to route to Vault for dev-cm."
  default     = "10.142.0.0/20"
}

variable "vault_dns_record_name" {
  type = "string"
  description = "The record to create on the wpesvc.net to point at Vault's internally facing Application Load Balancer."
  default     = "vault-dev"
}
