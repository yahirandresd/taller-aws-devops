pipeline {
  agent any
  tools {
    nodejs 'Node20'
    jdk 'Java17'
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Frontend build & tests') {
      steps {
        dir('frontend') {
          sh 'npm ci'
          sh 'npm test'
          sh 'npm run build'
        }
      }
    }
    stage('Backend tests & package') {
      steps {
        dir('backend') {
          sh 'mvn test'
          sh 'mvn package -DskipTests'
        }
      }
    }
    stage('Deploy DEV') {
      when { branch 'develop' }
      steps { sh './deploy.sh dev' }
    }
    stage('Deploy QA') {
      when { branch 'qa' }
      steps { sh './deploy.sh qa' }
    }
    stage('Deploy PDN') {
      when { branch 'main' }
      steps {
        input message: '¿Autorizar despliegue a PDN/producción?'
        sh './deploy.sh prod'
      }
    }
  }
  post {
    always {
      archiveArtifacts artifacts: 'frontend/dist/**,backend/target/*.jar', allowEmptyArchive: true
    }
  }
}
