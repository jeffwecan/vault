#!groovy
@Library('wpshared') _

String hipchatRoom = 'Vault Monitoring'
String masterBranch = 'master'
def terraform_environments = ['development']

timestamps {
	node('docker') {
		wpe.pipeline('Techops Deploy') {
			def terraformCredentials = [
				// for terraform validate, TODO: remove this context once shared var can do our validate and graph calls?
				string(credentialsId: 'TERRAFORM_AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
				string(credentialsId: 'TERRAFORM_AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY'),
			]
			try {
				stage('Lint') {
					withCredentials(terraformCredentials) {
						sh 'make --keep-going lint'
					}
				}

				if (env.BRANCH_NAME == masterBranch) {
					stage('Terraform Apply') {
						for (env_index = 0; env_index < terraform_environments.size(); env_index++) {
							terraform.apply {
								terraformDir = "./terraform/aws/" + terraform_environments[env_index]
								hipchatRoom = hipchatRoom
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
			} catch (error) {
				if (env.BRANCH_NAME == masterBranch) {
					hipchat.notify {
						room = hipchatRoom
						status = 'FAILED'
					}
				}
				throw error
			}
		}
	}
}
