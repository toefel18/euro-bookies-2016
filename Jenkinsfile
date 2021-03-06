#!groovy

stage 'compile & test'

pipelineStep('') {
    checkout scm

    dir('bookies-2016-app') {
        notifySlackIfFailed("compile and test") {
            sh 'npm install'
            sh 'npm test'
        }
    }
}

stage 'Build docker image'

pipelineStep('') {
    dir('bookies-2016-app') {
        notifySlackIfFailed("building docker image") {
            sh 'docker build --build-arg software_version=$(git rev-parse --short HEAD) --build-arg image_build_timestamp=$(date -u +%Y-%m-%dT%H:%M:%S%Z) -t softwarecraftsmanshipcgi/bookies-2016-app:$(git rev-parse --short HEAD) .'
            // it would be nice tag the image with latest as well for ease of use!
        }
    }
}

stage name: 'acceptance test', concurrency: 1

pipelineStep('') {

    // start a clean database using the mariadb docker image (The database is configured by providing environment variables using -e)
    // we use the name so we can reference to stop it later
    sh 'docker run -d --name=cucumber_bookies_db -p 7777:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=bookies_db -e MYSQL_USER=cucumber -e MYSQL_PASSWORD=cucumber mariadb'
    try {
        // update the database to the latest version using flyway. The database might not be up yet on slow nodes, so try 3 times
        retry(3) {
            sleep 20
            dir('bookies-2016-app-database') {
                // update the database to the latest known version using flyway, the version scripts are located in subdirectory sql
                sh 'flyway -user=cucumber -password=cucumber -url=\"jdbc:mysql://localhost:7777\" -schemas=bookies_db -locations=filesystem:sql migrate'
            }
        }

        // start the application and connect it to our test database, we cannot use localhost as the IP, that would not be able to go outside the container
        // to get the ip address we use $(ip route get 8.8.8.8 | head -1 | cut -d' ' -f8)
        sh 'docker run -d --name=cucumber_bookies_app -p 7778:8080 -e DB_CONNECTION_STRING=mysql://cucumber:cucumber@$(ip route get 8.8.8.8 | head -1 | cut -d\' \' -f8):7777/bookies_db softwarecraftsmanshipcgi/bookies-2016-app:$(git rev-parse --short HEAD)'
        try {
            dir('bookies-2016-app-acceptance-test') {
                // run a maven build that automatically executes cucumber acceptance tests
                notifySlackIfFailed("acceptance test") {
                    sh 'mvn clean install -Dapplication.url=http://localhost:7778'
                }
            }
        } finally {
            // remove the application container, to avoid building up a lot of waste
            sh 'docker rm -f cucumber_bookies_app'
        }
    } finally {
        sh 'docker rm -f cucumber_bookies_db'                  // clean up test database container
    }
}

stage 'upload to docker hub'

pipelineStep('') {

    notifySlackIfFailed("uploading to docker hub") {
        sh 'docker login --username=softwarecraftsmanshipcgi --password Welkom01!' // don't store this password here!
        sh 'docker push softwarecraftsmanshipcgi/bookies-2016-app:$(git rev-parse --short HEAD)'
    }
}

stage name: 'deploy staging', concurrency: 1

pipelineStep('') {

    dir('bookies-2016-app-deployment') {
        notifySlackIfFailed("deployment to staging") {
            sh 'ansible-playbook -i /home/ubuntu/euro-bookies-2016/ansible/staging -e "@bookies-deployment-variables.yml" -e "image_version=$(git rev-parse --short HEAD) app_deployment_dir=$(pwd)"  -e ansible_ssh_private_key_file=~/.ssh/workshop_ansiblecc_key deploy-application.yml'
            notifySuccessViaSlack "New version of bookies deployed to staging"
        }
    }
}

stage name: 'load test against staging', concurrency: 1

pipelineStep('') {

    dir('bookies-2016-app-load-test') {
        notifySlackIfFailed("load test") {
            // run the gatling tests using ansible (which calls maven, but ansible knows the host)
            sh 'ansible-playbook -i /home/ubuntu/euro-bookies-2016/ansible/staging run-gatling.yml'
        }
    }
}

stage name: 'deploy production', concurrency: 1
input "Deploy to production?"

pipelineStep('') {
    dir('bookies-2016-app-deployment') {
        notifySlackIfFailed("deployment to production") {
            sh 'ansible-playbook -i /home/ubuntu/euro-bookies-2016/ansible/production -e "@bookies-deployment-variables.yml" -e "image_version=$(git rev-parse --short HEAD) app_deployment_dir=$(pwd)" -e ansible_ssh_private_key_file=~/.ssh/workshop_ansiblecc_key deploy-application.yml'
            notifySuccessViaSlack "New version of bookies deployed to production"
        }
    }
}



/**
 * Wrapper around the body of a node, so that we can detect failures and take action (like messaging).
 * to unwrap: remove this method and replace 'pipelineStep' with 'node'
 *
 * Idea is taken from: http://stackoverflow.com/questions/36837683/how-to-perform-actions-for-failed-builds-in-jenkinsfile
 */
def pipelineStep(String label, Closure body) {
    node(label) {
        wrap([$class: 'TimestamperBuildWrapper']) {
            try {
                body.call()
            } catch (Exception e) {
                // normally we would include the stacktrace or the exception message, but this is blocked by script-security (must be whitelisted)!
                notifyFailureViaSlack("Failure in bookies pipelineStep, review logging for details");
                throw e; // rethrow so the build is considered failed
            }
        }
    }
}

/** rgbColorCode should be in the form of FF0000 (which produces red)*/
def sendSlack(String message, String rgbColorCode) {
    sh 'curl -X POST --data-urlencode payload=\'{"channel": "#builds","attachments":[{"fallback": "\'"$BRANCH_NAME"\': ' + message + '","color": "#' + rgbColorCode + '","fields": [{"short": false,"value": "\'"$BRANCH_NAME"\': ' + message + '"}],"mrkdwn_in": [ "pretext", "text", "fields"]}]}\' https://cgi-craftsmanship.slack.com/services/hooks/jenkins-ci?token=0YiLVF6DZUkYpXX403Iet104'
}

def notifySlackIfFailed(String taskName, Closure body) {
    try {
        body.call()
    } catch (Exception e) {
        // normally we would include the stacktrace or the exception message, but this is blocked by script-security (must be whitelisted)!
        notifyFailureViaSlack("${taskName} failed");
        throw e; // rethrow so the build is considered failed
    }
}

def notifyFailureViaSlack(String message) { sendSlack(message, "FF0000"); }

def notifySuccessViaSlack(String message) { sendSlack(message, "00FF00"); }
