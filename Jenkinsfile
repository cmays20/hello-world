#!/usr/bin/env groovy
def VERSION = 'UNKNOWN'

pipeline {
  agent none
  environment {
    DOCKER_REPO_NAME = "cmays/hello-world"
  }

  tools {
    jdk "Java8"
    maven "M3"
  }

  stages {
    stage('Build') {
      agent any
      steps {
        script  {
          VERSION = sh(script: 'mvn org.apache.maven.plugins:maven-help-plugin:3.1.0:evaluate -Dexpression=project.version -q -DforceStdout --batch-mode',returnStdout: true)
        }
        echo "${VERSION}"
        sh 'mvn verify'
      }
    }

    stage('Make Container') {
      agent any
      steps {
        sh "docker build -t ${DOCKER_REPO_NAME}:${VERSION} ."
      }
    }

    stage('Push Container') {
      agent any
      when {
        branch 'master'
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'docker-credentials', usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD')]) {
          sh "docker login -u ${USERNAME} -p ${PASSWORD}"
          sh "docker push ${DOCKER_REPO_NAME}:${VERSION}"
          echo "${VERSION}"
        }
      }
    }

    stage('Deploy') {
      agent any
      when {
        branch 'master'
      }
      steps {
        sh 'sed -e "s/:APP_ENV:/prod/g" -e "s|:APP_VERSION:|${VERSION}|g" config/marathon.json.template > marathon.json'
        sh '[ -d /usr/local/bin ] || sudo mkdir -p /usr/local/bin'
        sh 'curl https://downloads.dcos.io/binaries/cli/linux/x86-64/dcos-1.12/dcos -o dcos'
        sh 'sudo mv dcos /usr/local/bin'
        sh 'sudo chmod +x /usr/local/bin/dcos'
        sh 'dcos cluster setup https://cmays-demo-763478160.us-west-2.elb.amazonaws.com'
        sh 'dcos marathon app add marathon.json'
      }
    }
  }
}