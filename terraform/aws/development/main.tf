# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A VAULT SERVER CLUSTER AND A CONSUL SERVER CLUSTER IN AWS
# This cluster uses Consul, running in a separate cluster, as its storage backend.
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  version = "~> 1.1"
  region = "${var.aws_region}"
  assume_role {
    role_arn     = "${var.aws_role_arn}"
    session_name = "terraform_vault_development"
  }
}

provider "google" {
  version = "~> 1.1"
  project = "${var.gcp_project}"
  region = "${var.gcp_region}"
}

provider "template" {
  version = "~> 1.0"
}

terraform {
  required_version = ">= 0.9.3"
}

data "aws_ami" "vault-consul" {
  most_recent      = true

  filter {
    name   = "name"
    values = ["vault-consul-ubuntu-*"]
  }

  owners     = ["self"]
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE CLUSTERS IN THE DEFAULT VPC AND AVAILABILITY ZONES
# Using the default VPC and subnets makes this example easy to run and test, but it means Consul and Vault are
# accessible from the public Internet. In a production deployment, we strongly recommend deploying into a custom VPC
# and private subnets.
# ---------------------------------------------------------------------------------------------------------------------

module "vpc" "vault-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "terraform-vault-vpc"
  cidr = "${var.vpc_cidr}"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = "${var.vpc_private_subnets}"
  public_subnets  = "${var.vpc_public_subnets}"
  map_public_ip_on_launch = false  // TODO: turn this off after dev'in
  enable_nat_gateway = true
  enable_dns_support = true
  enable_dns_hostnames = true
//  enable_s3_endpoint = true

  private_propagating_vgws = [
    "${aws_vpn_gateway.aws-vpn-gw.id}"
  ]
  public_propagating_vgws = [
    "${aws_vpn_gateway.aws-vpn-gw.id}"
  ]

  tags = {
    Terraform = "true"
    Environment = "development"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE VAULT SERVER CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "vault_elb" {
  # Use version v0.0.1 of the vault-elb module
  source = "github.com/hashicorp/terraform-aws-vault//modules/vault-elb?ref=v0.0.7"
  name = "${var.vault_cluster_name}-elb"
  allowed_inbound_cidr_blocks = "${var.vpc_private_subnets}"
  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.private_subnets}"
//  availability_zones = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c", "${var.aws_region}d", "${var.aws_region}e", "${var.aws_region}f"]
}

module "vault_cluster" {
  source = "git::git@github.com:hashicorp/terraform-aws-vault.git//modules/vault-cluster?ref=v0.0.2"

  cluster_name  = "${var.vault_cluster_name}"
  cluster_size  = "${var.vault_cluster_size}"
  instance_type = "${var.vault_instance_type}"

  ami_id    = "${data.aws_ami.vault-consul.id}"
  user_data = "${data.template_file.user_data_vault_cluster.rendered}"

  s3_bucket_name          = "${var.s3_bucket_name}"
  force_destroy_s3_bucket = "${var.force_destroy_s3_bucket}"

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnets}"

  # To make testing easier, we allow requests from any IP address here but in a production deployment, we *strongly*
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.

  allowed_ssh_cidr_blocks            = "${var.allowed_ssh_cidr_blocks}"
  allowed_inbound_cidr_blocks        = "${var.allowed_inbound_cidr_blocks}"
  allowed_inbound_security_group_ids = []
  ssh_key_name                       = "${var.ssh_key_name}"


  load_balancers = ["${module.vault_elb.load_balancer_name}"]
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

  vpc_id     = "${module.vpc.vpc_id}"
  subnet_ids = "${module.vpc.public_subnets}"

  # To make testing easier, we allow Consul and SSH requests from any IP address here but in a production
  # deployment, we strongly recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.

  allowed_ssh_cidr_blocks     = "${var.allowed_ssh_cidr_blocks}"
  allowed_inbound_cidr_blocks = "${var.allowed_inbound_cidr_blocks}"
  ssh_key_name                = "${var.ssh_key_name}"
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
