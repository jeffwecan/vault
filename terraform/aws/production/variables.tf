# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "s3_bucket_name" {
  description = "The name of an S3 bucket to create and use as a storage backend. Note: S3 bucket names must be *globally* unique."
  default = "vault.wpengine.io"
}

variable "ssh_key_name" {
  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
  default = "cm"
}

variable "aws_role_arn" {
  description = "AWS role ARN to assume when doing deployments"
  default = "arn:aws:iam::770273818880:role/wpengine/robots/TerraformApplier"
}

variable "consul_bootstrap_playbook" {
    description = "Playbook to finalize a consul instance's configuration"
    default = "/opt/ansible-vault/vault-aws-bootstrap.yml"
}

variable "consul_bootstrap_vars" {
    description = "Ansible variables for use when finalizing a consul instance's configuration"
    default = "/opt/ansible-vault/roles/consul/vars/bootstrap_aws_dev.yml"
}

variable "vault_bootstrap_playbook" {
    description = "Playbook to finalize a vault instance's configuration"
    default = "/opt/ansible-vault/consul-aws-bootstrap.yml"
}

variable "vault_bootstrap_vars" {
    description = "Ansible variables for use when finalizing a vault instance's configuration"
    default = "/opt/ansible-vault/roles/vault/vars/bootstrap_aws_dev.yml"
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region to deploy into (e.g. us-east-1)."
  default     = "us-east-1"
}

variable "vault_cluster_name" {
  description = "What to name the Vault server cluster and all of its associated resources"
  default     = "vault-example"
}

variable "consul_cluster_name" {
  description = "What to name the Consul server cluster and all of its associated resources"
  default     = "consul-example"
}

variable "vault_cluster_size" {
  description = "The number of Vault server nodes to deploy. We strongly recommend using 3 or 5."
  default     = 3
}

variable "consul_cluster_size" {
  description = "The number of Consul server nodes to deploy. We strongly recommend using 3 or 5."
  default     = 3
}

variable "vault_instance_type" {
  description = "The type of EC2 Instance to run in the Vault ASG"
  default     = "t2.micro"
}

variable "consul_instance_type" {
  description = "The type of EC2 Instance to run in the Consul ASG"
  default     = "t2.micro"
}

variable "consul_cluster_tag_key" {
  description = "The tag the Consul EC2 Instances will look for to automatically discover each other and form a cluster."
  default     = "consul-servers"
}

variable "force_destroy_s3_bucket" {
  description = "If you set this to true, when you run terraform destroy, this tells Terraform to delete all the objects in the S3 bucket used for backend storage. You should NOT set this to true in production or you risk losing all your data! This property is only here so automated tests of this module can clean up after themselves."
  default     = false
}

variable "dev_cm_ip" {
    description = "IP address for dev-cm"
    default = "0.0.2"
}