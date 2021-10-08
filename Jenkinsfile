pipeline {
  agent any
  stages {
    stage('Prepare') {
      steps {
        sh 'echo "IMG_NAME=WaziGate" > config'
      }
    }
    stage('Build') {
      steps {
        sh 'sudo ./build.sh'
      }
    }
  }
  post {
    success {
      echo 'Success!'
    }
    failure {
      echo 'Failure!'
    }
    unstable {
      echo 'Unstable'
    }
  }
}
