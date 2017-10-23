# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A VAULT SERVER CLUSTER AND A CONSUL SERVER CLUSTER IN AWS
# This is an example of how to use the vault-cluster module to deploy a Vault cluster in AWS. This cluster uses Consul,
# running in a separate cluster, as its storage backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = "${var.aws_region}"
  assume_role {
    role_arn     = "${var.aws_role_arn}"
    session_name = "terraform_vault_production"
//    external_id  = "EXTERNAL_ID"
  }
}

terraform {
  required_version = ">= 0.9.3"
}

//data "aws_ami_ids" "ubuntu" {
//  owners = ["099720109477"]
//
//  filter {
//    name   = "name"
//    values = ["ubuntu/images/ubuntu-*-*-amd64-server-*"]
//  }
//}

data "aws_ami" "vault-consul" {
  most_recent      = true
//  executable_users = ["self"]

//  filter {
//    name   = "owner-alias"
//    values = ["self"]
//  }

  filter {
    name   = "name"
    values = ["vault-consul-ubuntu-*"]
  }

//  name_regex = "^myami-\\d{3}"
  owners     = ["self"]
}

//resource "aws_ami_copy" "vault-consul-corp" {
//  name              = "vault-consul-ubuntu-{{ user `version` | clean_ami_name}}"
//  description       = "An Ubuntu 16.04 AMI that has Vault and Consul installed.",
//  source_ami_id     = "${data.aws_ami.vault-consul-dev.id}"
//  source_ami_region = "${var.aws_region}"
//
//  tags {
//    Name = "vault-consul-ubuntu"
//  }
//}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_cluster" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  source = "git::git@github.com:hashicorp/terraform-aws-vault.git//modules/vault-cluster?ref=v0.0.2"

  cluster_name  = "${var.vault_cluster_name}"
  cluster_size  = "${var.vault_cluster_size}"
  instance_type = "${var.vault_instance_type}"

  ami_id    = "${data.aws_ami.vault-consul.id}"
  user_data = "${data.template_file.user_data_vault_cluster.rendered}"

  s3_bucket_name          = "${var.s3_bucket_name}"
  force_destroy_s3_bucket = "${var.force_destroy_s3_bucket}"

  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = "${data.aws_subnet_ids.default.ids}"

  # To make testing easier, we allow requests from any IP address here but in a production deployment, we *strongly*
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.

  allowed_ssh_cidr_blocks            = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks        = ["0.0.0.0/0"]
  allowed_inbound_security_group_ids = []
  ssh_key_name                       = "${var.ssh_key_name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH IAM POLICIES FOR CONSUL
# To allow our Vault servers to automatically discover the Consul servers, we need to give them the IAM permissions from
# the Consul AWS Module's consul-iam-policies module.
# ---------------------------------------------------------------------------------------------------------------------

module "consul_iam_policies_servers" {
  source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-iam-policies?ref=v0.0.2"

  iam_role_id = "${module.vault_cluster.iam_role_id}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH VAULT SERVER WHEN IT'S BOOTING
# This script will configure and start Vault
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_vault_cluster" {
  template = "${file("${path.module}/user-data-vault.sh")}"

  vars {
    aws_region               = "${var.aws_region}"
    s3_bucket_name           = "${var.s3_bucket_name}"
    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
    consul_cluster_tag_value = "${var.consul_cluster_name}"
    vault_bootstrap_playbook = "${var.vault_bootstrap_playbook}"
    vault_bootstrap_vars     = "${var.vault_bootstrap_vars}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CONSUL SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "consul_cluster" {
  source = "git::git@github.com:hashicorp/terraform-aws-consul.git//modules/consul-cluster?ref=v0.0.2"

  cluster_name  = "${var.consul_cluster_name}"
  cluster_size  = "${var.consul_cluster_size}"
  instance_type = "${var.consul_instance_type}"

  # The EC2 Instances will use these tags to automatically discover each other and form a cluster
  cluster_tag_key   = "${var.consul_cluster_tag_key}"
  cluster_tag_value = "${var.consul_cluster_name}"

  ami_id    = "${data.aws_ami.vault-consul.id}"
  user_data = "${data.template_file.user_data_consul.rendered}"

  vpc_id     = "${data.aws_vpc.default.id}"
  subnet_ids = "${data.aws_subnet_ids.default.ids}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.

  allowed_ssh_cidr_blocks     = ["0.0.0.0/0"]
  allowed_inbound_cidr_blocks = ["0.0.0.0/0"]
  ssh_key_name                = "${var.ssh_key_name}"
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH CONSUL SERVER WHEN IT'S BOOTING
# This script will configure and start Consul
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data_consul" {
  template = "${file("${path.module}/user-data-consul.sh")}"

  vars {
    consul_cluster_tag_key   = "${var.consul_cluster_tag_key}"
    consul_cluster_tag_value = "${var.consul_cluster_name}"
    consul_bootstrap_playbook = "${var.consul_bootstrap_playbook}"
    consul_bootstrap_vars     = "${var.consul_bootstrap_vars}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CLUSTERS IN THE DEFAULT VPC AND AVAILABILITY ZONES
# Using the default VPC and subnets makes this example easy to run and test, but it means Consul and Vault are
# accessible from the public Internet. In a production deployment, we strongly recommend deploying into a custom VPC
# and private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = "${data.aws_vpc.default.id}"
}
