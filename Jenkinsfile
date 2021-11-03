pipeline {
  agent any
  stages {
    stage('Prepare') {
      steps {
        sh 'echo "IMG_NAME=WaziGate" > config'
        sh 'echo "IMG_DATE=nightly'
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
  }
  post {
    success {
      archiveArtifacts artifacts: 'deploy/*', fingerprint: true
    }
    failure {
      echo 'Failure!'
    }
    unstable {
      echo 'Unstable'
    }
  }
}
