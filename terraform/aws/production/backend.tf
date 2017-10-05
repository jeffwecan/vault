terraform {
  backend "s3" {
    role_arn = "arn:aws:iam::770273818880:role/wpengine/robots/TerraformStateMaintainer"
    bucket   = "wpengine-terraform-state"
    key      = "vault/vault-staging.tfstate"
    region   = "us-east-1"
    encrypt  = "true"

    # TODO: Unique lock table per stack?
    dynamodb_table = "wpengine-terraform-lock"
  }
}
