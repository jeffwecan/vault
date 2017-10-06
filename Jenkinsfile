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
		String	hipchatRoom = "Vault Monitoring"
        // IMAGE_TAG is used in docker-compose to ensure uniqueness of containers and networks.
        withEnv(["IMAGE_TAG=${IMAGE_TAG}", "TLS_OWNER=${TLS_OWNER}"]) {
            try {
                stage('Lint Markdown') {
					sh 'make markdownlint'
				}

                stage('Lint Ansible') {
					sh 'make ansiblelint'
				}

                stage('Test') {
                     sh 'make test'
                }

                if (env.BRANCH_NAME == 'terraform_vault') {  // if BRANCH_NAME == some_dev_branch and/or some_master_branch?
					def packerCredentials = [
						string(credentialsId: 'AWS_ACCESS_KEY_ID_DEV', variable: 'AWS_ACCESS_KEY_ID'),
						string(credentialsId: 'AWS_SECRET_ACCESS_KEY_DEV', variable: 'AWS_SECRET_ACCESS_KEY'),
					]
					withCredentials(packerCredentials) {
						stage('Build AMI') {
							sh 'echo Saving on time by not building the AMI atm...'
							sh 'make build-ami'
						}
					}
					stage('Deploy to Dev') {
						// need dev credentials to launch encrypted AMI? can we encrypt the AMIs with a shared vault AMI key???
						withCredentials(packerCredentials) {
							terraform.apply {
								terraformDir = "./terraform/aws/development"
								hipchatRoom = hipchatRoom
							}
						}
					}

					stage('Smoke Dev') {
						sh 'make smoke-dev'
					}

					stage('Deploy to Production') {
						terraform.plan {
							terraformDir = "./terraform/aws/corporate"
							hipchatRoom = hipchatRoom
						}
					}

					stage('Smoke Production') {
						sh 'make smoke-production'
					}

                } else {
					// Just do terraform plan
					stage('TF Plan - Dev') {
						terraform.plan {
							terraformDir = "./terraform/aws/development"
							hipchatRoom = hipchatRoom
						}
					}
					stage('TF Plan - Corp') {
						terraform.plan {
							terraformDir = "./terraform/aws/corporate"
							hipchatRoom = hipchatRoom
						}
					}
                }
            } catch (error) {
				if (env.BRANCH_NAME == 'terraform_vault') {
					hipchat.notify {
						room = hipchatRoom
						status = 'FAILED'
					}
				}
            	throw error
            } finally {
				workspace.cleanUp()
            }
        }
    }
}
