#!groovy
@Library('wpshared') _

def terraform_environments = ['development', 'corporate']

timestamps {
	node('docker') {
		wpe.pipeline("Techops Deploy") {
			stage('Lint') {
				sh 'make --keep-going lint'
			}

			if (env.BRANCH_NAME == "master") {
				stage('Terraform Apply') {
					for (env_index = 0; env_index < terraform_environments.size(); env_index++) {
						terraform.apply {
							terraformDir = "./terraform/aws/" + terraform_environments[env_index]
							hipchatRoom = "Techops Deploy"
						}
					}
				}
			} else {
				stage('Terraform Plan') {
					for (env_index = 0; env_index < terraform_environments.size(); env_index++) {
						terraform.plan {
							terraformDir = "./terraform/aws/" + terraform_environments[env_index]
						}
					}
				}
			}
		}
	}
}
