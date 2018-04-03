#!groovy
@Library('wpshared') _

timestamps {
	node('docker') {
		wpe.pipeline('Techops Deploy') {
			String	hipchatRoom = "Vault Monitoring"
			String	masterBranch = "master"

			try {
				stage('Lint') {
					sh 'make --keep-going lint'
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
