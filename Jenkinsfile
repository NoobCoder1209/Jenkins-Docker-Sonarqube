// Jenkinsfile — Jenkins-Docker-Sonarqube portfolio demo
// Single-node Jenkins (agent any), SonarQube reachable as http://sonarqube:9000,
// SonarQube server registered in JCasC under the name "sonarqube",
// sonar-scanner provisioned via JCasC tool installer named "sonar-scanner".

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAME = 'jenkins-docker-sonarqube-demo'
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
        // SONAR_HOST_URL and SONAR_AUTH_TOKEN are injected by withSonarQubeEnv.
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Setup Python') {
            steps {
                sh '''
                    python3 -m venv .venv
                    . .venv/bin/activate
                    pip install --quiet --upgrade pip
                    pip install --quiet -r requirements-dev.txt
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '. .venv/bin/activate && ruff check .'
            }
        }

        stage('Test') {
            steps {
                sh '. .venv/bin/activate && pytest --cov=app --cov-report=xml --cov-report=term --junitxml=junit.xml'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'junit.xml'
                    archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv('sonarqube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -t ${IMAGE_NAME}:latest ."
            }
        }

        // Publish stage left commented out by design — the demo is self-contained
        // and does not push to an external registry.
        //
        // stage('Publish Image') {
        //     when { branch 'main' }
        //     steps {
        //         withCredentials([usernamePassword(
        //             credentialsId: 'registry-creds',
        //             usernameVariable: 'REG_USER',
        //             passwordVariable: 'REG_PASS')]) {
        //             sh '''
        //                 echo "$REG_PASS" | docker login -u "$REG_USER" --password-stdin
        //                 docker tag  ${IMAGE_NAME}:${IMAGE_TAG} ${REG_USER}/${IMAGE_NAME}:${IMAGE_TAG}
        //                 docker push ${REG_USER}/${IMAGE_NAME}:${IMAGE_TAG}
        //             '''
        //         }
        //     }
        // }
    }

    post {
        always { cleanWs() }
    }
}
