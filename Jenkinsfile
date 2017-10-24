#!groovy
@Library('wpshared') _

timestamps {
	node('docker') {
		// This pipeline var does nice things like automatically cleanup your workspace and hipchat the provided room
		// when master builds fail. Docs are available at:
		// https://jenkins.wpengine.io/job/WPEngineGitHubRepos/job/jenkins_shared_library/job/master/pipeline-syntax/globals#wpe
		wpe.pipeline('Vault Monitoring') {
			String	SHORT_GIT_COMMIT = GIT_COMMIT.take(6)
			String  IMAGE_TAG = "${BUILD_NUMBER}-${SHORT_GIT_COMMIT}"
			String  IMAGE_NAME = "vault${IMAGE_TAG}"
			String	TLS_OWNER = "root"
			String	hipchatRoom = "Vault Monitoring"
			String	masterBranch = "terraform_vault" // some day master?
			def packerCredentials = [
				string(credentialsId: 'AWS_ACCESS_KEY_ID_DEV', variable: 'AWS_ACCESS_KEY_ID'),
				string(credentialsId: 'AWS_SECRET_ACCESS_KEY_DEV', variable: 'AWS_SECRET_ACCESS_KEY'),
			]
			def terraformCredentials = [
				// for terraform validate, TODO: remove this context once shared var can do our validate and graph calls?
				string(credentialsId: 'TERRAFORM_AWS_ACCESS_KEY_ID', variable: 'AWS_ACCESS_KEY_ID'),
				string(credentialsId: 'TERRAFORM_AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY'),
			]

			// IMAGE_TAG is used in docker-compose to ensure uniqueness of containers and networks.
			withEnv(["IMAGE_TAG=${IMAGE_TAG}", "TLS_OWNER=${TLS_OWNER}"]) {
				try {
					stage('Lint') {
						withCredentials(terraformCredentials) {
							sh 'make lint'
						}
					}

					stage('Test') {
						 sh 'make test'
						 junit 'artifacts/ansible/package-vault-*tags_bootstrap-*.xml'
						 junit 'artifacts/molecule/*.xml'
						 //sh 'echo hullo'
					}

					if (env.BRANCH_NAME == masterBranch) {  // if BRANCH_NAME == some_dev_branch and/or some_master_branch?
						milestone 1 // 'Vault AMI Baked'
						lock(resource: 'vault-packer-build-ami', inversePrecedence: true) {
							withCredentials(packerCredentials) {
								try {
									stage('Build AMI') {
										//sh 'echo hullo'
										sh 'make packer-build-ami'
									}
								} catch(error) {
									echo "First build failed, sometimes packer randomly times out waiting for SSH?"
									retry(1) {
										input "Retry the job?"
										sh 'make packer-build-ami'
									}
								}
							}
						}

						milestone 2 // 'Vault Terraform Module Deployed to AWS Development'
						lock(resource: 'vault-terraform-deploy-to-dev', inversePrecedence: true) {
							stage('Deploy to Dev') {
								terraform.apply {
									terraformDir = "./terraform/aws/development"
									hipchatRoom = "Vault Monitoring"
								}
							}

							stage('Smoke Dev') {
								sh 'make smoke-development'
								// TODO: Roll back on failure?
								hipchat.notify {
									room = hipchatRoom
									status = 'SUCCESS'
									message = "New AMI Deployed to Development"
								}
							}
						}

						milestone 3 // 'Vault Terraform Module Deployed to AWS Corporate / Production'
						lock(resource: 'vault-terraform-deploy-to-prod', inversePrecedence: true) {
							stage('Deploy(plan) to Production') {
								sh 'echo maybe deploy to prod someday...'

								stage('Smoke Production') {
									sh 'make smoke-production'
								}
							}
						}
					} else {
						// Just do terraform plan
						stage('TF Plan - Dev') {
							terraform.plan {
								terraformDir = "./terraform/aws/development"
								hipchatRoom = "Vault Monitoring"
							}
						}
						stage('TF Plan - Corp') {
							terraform.plan {
								terraformDir = "./terraform/aws/production"
								hipchatRoom = "Vault Monitoring"
							}
						}
					}

					stage('Save Graphs') {
						withCredentials(terraformCredentials) {
							sh 'echo maybe make an artifact some day?'
							// sh 'make terraform-graph'
                    		// archiveArtifacts 'artifacts/*_tf.gz'
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
				} finally {
					workspace.cleanUp()
				}
			}
		}
	}
}
