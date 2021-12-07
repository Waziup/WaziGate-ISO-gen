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
        sh 'echo "DEPLOY_ZIP=0" >> config'
      }
    }
    stage('Build') {
      steps {
        sh 'sudo CLEAN=1 ./build.sh'
      }
    }
    stage('Deploy') {
      steps {
        dir('deploy') {
          catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            // Flash to a SD card connected on /dev/sda
            sh "sudo dd bs=4M if=nightly-WaziGate.img of=/dev/sda conv=sync"
            sh "sudo zip image_nightly-WaziGate.zip nightly-WaziGate.img"
          }
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
