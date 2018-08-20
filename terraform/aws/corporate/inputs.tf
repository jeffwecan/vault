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

variable "vault_load_balancer_arn" {
  type        = "string"
  description = "The Amazon Resource Name (ARN) for the internally-facing Application Load Balancer for Vault nodes"
  default     = "arn:aws:elasticloadbalancing:us-east-1:770273818880:loadbalancer/app/vault-Appli-3IJWON45DA8X/cfaa06055210970e"
}

variable "vault_vpc_id" {
  type        = "string"
  description = "The VPC ID containing the vault nodes"
  default     = "vpc-d762c8af"
}

variable "vault_route_table_id" {
  type        = "string"
  description = "The VPC route table ID for vault nodes"
  default     = "rtb-8d622af7"
}

variable "vault_load_balancer_security_group_id" {
  type        = "string"
  description = "The VPC security group ID for the Vault node load balancer"
  default     = "sg-cb97a3b9"
}

variable "vault_security_group_id" {
  type        = "string"
  description = "The VPC security group ID for the Vault nodes / ec2 instances themselves."
  default     = "sg-49af9b3b"
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

variable "corporate_core_metrics_subnet_id" {
  type        = "string"
  description = "Subnet ID for the metrics* instances in the 'CorporateCore' VPC"
  default     = "subnet-d3b549f9"
}

variable "metricsdb_security_group_id" {
  type        = "string"
  description = "The VPC security group ID for the metricsdb nodes / ec2 instance."
  default     = "sg-f4065b8d"
}

variable "cm_subnet_id" {
  type        = "string"
  description = "Subnet ID for the cm-aws instance"
  default     = "subnet-2273fc1f"
}

variable "jenkins_subnet_id" {
  type        = "string"
  description = "Subnet ID for the Jenkins master instance"
  default     = "subnet-e975a9c4"
}

variable "zabbix_subnet_id" {
  type        = "string"
  description = "Subnet ID for the zabbix 'main' instance in the 'Zabbix' VPC."
  default     = "subnet-eba99e9d"
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
