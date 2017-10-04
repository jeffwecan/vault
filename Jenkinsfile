#!groovy
@Library('wpshared') _

node('docker') {
    // This pipeline var does nice things like automatically cleanup your workspace and hipchat the provided room
    // when master builds fail. Docs are available at:
    // https://jenkins.wpengine.io/job/WPEngineGitHubRepos/job/jenkins_shared_library/job/master/pipeline-syntax/globals#wpe
    wpe.pipeline('Vault Monitoring') {
        String  IMAGE_TAG = ":${BUILD_NUMBER}.${GIT_COMMIT}"
        String  IMAGE_NAME = "vault${IMAGE_TAG}"
		String	TLS_OWNER = "root"
        // IMAGE_TAG is used in docker-compose to ensure uniqueness of containers and networks.
        withEnv(["IMAGE_TAG=${IMAGE_TAG}", "TLS_OWNER=${TLS_OWNER}"]) {
            try {

                stage('Lint Markdown') {
					sh 'make markdownlint'
				}

                stage('Lint Ansible') {
					//sh 'make ansiblelint'
					sh 'echo TODO: uncomment make ansiblelint'
				}

                stage('Test') {
                     // sh 'make test'
					 sh 'echo TODO: uncomment make test'
                }
                if (env.BRANCH_NAME == 'terraform_vault') {  // if BRANCH_NAME == some_dev_branch and/or some_master_branch?
					def packerCredentials = [
						string(credentialsId: 'AWS_ACCESS_KEY_ID_DEV', variable: 'AWS_ACCESS_KEY_ID'),
						string(credentialsId: 'AWS_SECRET_ACCESS_KEY_DEV', variable: 'AWS_SECRET_ACCESS_KEY'),
					]
//					withCredentials(packerCredentials) {
//						stage('Build AMI') {
//							sh 'make build-ami'
//						}
//					}
					withCredentials(packerCredentials) {
						stage('Deploy to Dev') {
							terraform.plan {
								terraformDir = "./terraform/aws/"
							}
						}
					}
                } else {
           			// Just do a plan
					stage('Deploy to Dev') {
						terraform.plan {
							terraformDir = "./terraform/aws/"
						}
					}
                }
            }
            finally {
                sh "echo finally'!'"
            }
        }
    }
}
