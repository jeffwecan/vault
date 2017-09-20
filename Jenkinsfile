#!groovy
@Library('wpshared') _

node('docker') {
    // This pipeline var does nice things like automatically cleanup your workspace and hipchat the provided room
    // when master builds fail. Docs are available at:
    // https://jenkins.wpengine.io/job/WPEngineGitHubRepos/job/jenkins_shared_library/job/master/pipeline-syntax/globals#wpe
    wpe.pipeline('Vault Monitoring') {
        String  IMAGE_TAG = ":${BUILD_NUMBER}.${GIT_COMMIT}"
        String  IMAGE_NAME = "vault${IMAGE_TAG}"

        // IMAGE_TAG is used in docker-compose to ensure uniqueness of containers and networks.
        withEnv(["IMAGE_TAG=${IMAGE_TAG}"]) {
            try {
                stage('Build') {
                    sh 'make build'
                }

                stage('Test') {
                    sh 'make test'
                    junit 'vault/artifacts/junit.xml'
                    coverage.publish 'vault/artifacts/coverage.xml'
                    publishHTML (target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: false,
                        keepAll: true,
                        reportDir: 'vault/artifacts/coverage',
                        reportFiles: '*',
                        reportName: 'Test Coverage'
                    ])
                }

                if (env.BRANCH_NAME == 'master') {
                    milestone 1
                    // Only allow one deploy at a time
                    lock(resource: 'vault_deploy', inversePrecedence:true) {
                        // Any older builds that reach milestone after a more recent build will be aborted
                        milestone 2

                        stage('Publish To Corporate Registry') {
                            // Tag the images from make build with the registry appropriate names
                            dockerRegistry.publishImage {
                                environment = 'corporate'
                                image = IMAGE_NAME
                            }
                        }

                        stage('Terraform Staging') {
                            withCredentials([string(credentialsId: 'vault-staging-db-password', variable: 'TF_VAR_db_password')]) {
                                terraform.apply {
                                    terraformDir = "./deploy/terraform/staging"
                                    hipchatRoom = "Vault Monitoring"
                                    envVars = ['TF_VAR_db_password']
                                }
                            }
                        }

                        stage('Deploy Staging') {
                            def registryEnv = dockerRegistry.environment('corporate')
                            helm.deploy {
                                wpeEnv = 'corporate-staging'
                                releaseName = 'vault-staging'
                                chart = './charts/vault'
                                values = [
                                    "app.image": registryEnv.imageName(IMAGE_NAME),
                                    "environment": "staging",
                                    "django.settingsModule": "config.settings.staging"
                                ]
                            }
                        }

                        // TODO: Re-enable when DNS entries are set up
                        // stage('Smoke Staging') {
                            // sh "make smoke-staging"
                        // }

                        stage('Terraform Production') {
                            withCredentials([string(credentialsId: 'vault-production-db-password', variable: 'TF_VAR_db_password')]) {
                                terraform.apply {
                                    terraformDir = "./deploy/terraform/production"
                                    hipchatRoom = "Vault Monitoring"
                                    envVars = ['TF_VAR_db_password']
                                }
                            }
                        }
                        stage('Deploy Production') {
                            def registryEnv = dockerRegistry.environment('corporate')
                            helm.deploy {
                                wpeEnv = 'corporate-production'
                                releaseName = 'vault-production'
                                chart = './charts/vault'
                                values = [
                                    "app.image": registryEnv.imageName(IMAGE_NAME)
                                ]
                            }
                        }

                        // TODO: Re-enable when DNS entries are set up
                        // stage('Smoke Production') {
                            // sh "make smoke-production"
                        // }
                    }
                }
            }
            finally {
                sh "docker-compose down"
            }
        }
    }
}
