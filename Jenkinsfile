#!/usr/bin/env groovy
def VERSION = 'UNKNOWN'

pipeline {
  agent none
  environment {
    DOCKER_REPO_NAME = "cmays/hello-world"
  }

  tools {
    maven "M3"
  }

  stages {
    stage('Build') {
      agent {label 'kube-slave'}
      steps {
        container('java') {
          sh 'mvn org.apache.maven.plugins:maven-help-plugin:3.1.0:evaluate -Dexpression=project.version'
          script  {
            VERSION = sh(script: 'mvn org.apache.maven.plugins:maven-help-plugin:3.1.0:evaluate -Dexpression=project.version -q -DforceStdout --batch-mode',returnStdout: true)
          }
          sh 'mvn verify'
        }
      }
    }

    stage('Make Container') {
      agent {label 'kube-slave'}
      steps {
        container('dind') {
          sh "docker build --network host -t ${DOCKER_REPO_NAME}:${VERSION} ."
        }
      }
    }

    stage('Push Container') {
      agent {label 'kube-slave'}
      when {
        branch 'master'
      }
      steps {
          container('dind') {
          withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
            sh "docker login -u ${USERNAME} -p ${PASSWORD}"
            sh "docker push ${DOCKER_REPO_NAME}:${VERSION}"
            echo "${VERSION}"
          }
        }
      }
    }
  }
}
