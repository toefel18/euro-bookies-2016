#!groovy
node {
    checkout scm
    dir ('bookies-2016-app') {
        stage 'compile & test bookies-2016-app'
        sh 'npm install'
        sh 'npm test'

        stage 'Build docker image'
        echo 'issue docker build command'
    }
}