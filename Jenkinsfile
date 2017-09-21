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
            }
            finally {
                sh "echo finally'!'"
            }
        }
    }
}
