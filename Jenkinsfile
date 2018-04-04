#!groovy
@Library('wpshared') _

String hipchatRoom = 'Techops Deploy'
String masterBranch = 'master'
def terraform_environments = ['development']

timestamps {
	node('docker') {
		wpe.pipeline(hipchatRoom) {
			try {
				stage('Lint') {
					sh 'make --keep-going lint'
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
