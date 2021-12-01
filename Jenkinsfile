pipeline {
  agent any
  stages {
    stage('Prepare') {
      steps {
        sh 'echo "IMG_NAME=WaziGate" > config'
        sh 'echo "IMG_DATE=nightly" >> config'
        sh 'echo "ENABLE_SSH=1" >> config'
        sh 'echo "FIRST_USER_PASS=loragateway" >> config'
        sh 'echo "TARGET_HOSTNAME=wazigate" >> config'
        sh 'echo "PI_GEN_REPO=https://github.com/Waziup/WaziGate-ISO-gen" >> config'
        sh 'echo "TARGET_HOSTNAME=wazigate" >> config'
      }
    }
    stage('Build') {
      steps {
        sh 'sudo CLEAN=1 ./build.sh'
      }
    }
    stage('Stage') {
      steps {
        sh "sudo sshpass -p loragateway ssh pi@$WAZIGATE_IP \\'sudo reboot now\\'"
      }
    }
    stage('Test') {
      steps {
        dir('tests'){
          sh 'sudo -E python3 tests.py'
        }
      }
    }
  }
  post {
    success {
      archiveArtifacts artifacts: 'deploy/*', fingerprint: true
    }
  }
}
