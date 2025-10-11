@Library('Shared') _
pipeline {
    agent any

    environment {
        SONAR_HOME = tool "Sonar"
    }

    parameters {
        string(
            name: 'FRONTEND_DOCKER_TAG',
            defaultValue: '',
            description: 'Setting docker image for latest push'
        )
        string(
            name: 'BACKEND_DOCKER_TAG',
            defaultValue: '',
            description: 'Setting docker image for latest push'
        )
    }

    stages {
        stage("Validate Parameters") {
            steps {
                script {
                    if (params.FRONTEND_DOCKER_TAG == '' || params.BACKEND_DOCKER_TAG == '') {
                        error("FRONTEND_DOCKER_TAG and BACKEND_DOCKER_TAG must be provided.")
                    }
                }
            }
        }

        stage("Workspace cleanup") {
            steps {
                script {
                    cleanWs()
                }
            }
        }

        stage("Git: Code Checkout") {
            steps {
                script {
                    code_checkout(
                        "https://github.com/DhruvMaradiya/Wanderlust-Mega-Project.git",
                        "main"
                    )
                }
            }
        }

        stage("OWASP: Dependency check") {
            steps {
                script {
                    owasp_dependency()
                }
            }
        }

        stage("SonarQube: Code Analysis") {
            steps {
                script {
                    sonarqube_analysis("Sonar", "wanderlust", "wanderlust")
                }
            }
        }

        stage("SonarQube: Code Quality Gates") {
            steps {
                script {
                    sonarqube_code_quality()
                }
            }
        }

        stage("Exporting environment variables") {
            parallel {
                stage("Backend env setup") {
                    steps {
                        withCredentials([file(credentialsId: 'gcp-key', variable: 'KEY')]) {
                            dir('Automations') {
                                sh '''
                                    gcloud auth activate-service-account --key-file=$KEY
                                    bash updatebackendnew.sh
                                '''
                            }
                        }
                    }
                }

                stage("Frontend env setup") {
                    steps {
                        withCredentials([file(credentialsId: 'gcp-key', variable: 'KEY')]) {
                            dir('Automations') {
                                sh '''
                                    gcloud auth activate-service-account --key-file=$KEY
                                    bash updatefrontendnew.sh
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage("Docker: Build Images") {
            steps {
                script {
                    dir('backend') {
                        docker_build("wanderlust-backend-beta", "${params.BACKEND_DOCKER_TAG}", "dhruv4810")
                    }

                    dir('frontend') {
                        docker_build("wanderlust-frontend-beta", "${params.FRONTEND_DOCKER_TAG}", "dhruv4810")
                    }
                }
            }
        }

        stage("Docker: Push to DockerHub") {
            steps {
                script {
                    docker_push("wanderlust-backend-beta", "${params.BACKEND_DOCKER_TAG}", "dhruv4810")
                    docker_push("wanderlust-frontend-beta", "${params.FRONTEND_DOCKER_TAG}", "dhruv4810")
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: '*.xml', followSymlinks: false
            build job: "pipeline-cd", parameters: [
                string(name: 'FRONTEND_DOCKER_TAG', value: "${params.FRONTEND_DOCKER_TAG}"),
                string(name: 'BACKEND_DOCKER_TAG', value: "${params.BACKEND_DOCKER_TAG}")
            ]
        }
    }
}
