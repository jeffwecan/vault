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

                stage('Lint Ansible') {
                    sh 'make test-ansible'
                }

                stage('Test Packer Template') {
                    sh 'make test-packer'
                }
            }
            finally {
                sh "echo finally'!'"
            }
        }
    }
}
