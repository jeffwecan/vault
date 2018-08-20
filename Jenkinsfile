#!groovy
@Library('wpshared') _

def terraform_version = "0.11.3"
def terraform_environments = ['development', 'corporate']

timestamps {
	node('docker') {
		wpe.pipeline("Techops Deploy") {
			stage('Lint') {
				sh 'make --keep-going lint'
			}

			if (env.BRANCH_NAME == "master") {
				stage('Terraform Apply - Dev') {
					terraform.apply {
						terraformDir = "./terraform/aws/development"
						hipchatRoom = "Techops Deploy"
						terraformVersion = terraform_version
					}
				}
			} else {
				stage('Terraform Plan') {
					for (env_index = 0; env_index < terraform_environments.size(); env_index++) {
						terraform.plan {
							terraformDir = "./terraform/aws/${terraform_environments[env_index]}"
							hipchatRoom = "Techops Deploy"
							terraformVersion = terraform_version
						}
					}
				}
			}
		}
	}
}
