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
    stage('Finalize') {
      steps {
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
