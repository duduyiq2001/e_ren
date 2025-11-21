// E-Ren CI Pipeline using Hext (Docker-in-Docker approach)
// Runs on: Push to any branch, Pull Requests, PR comments (/retest)

pipeline {
  agent none

  properties([
    // GitHub integration
    githubProjectProperty(projectUrlStr: 'https://github.com/duduyiq2001/e_ren'),

    // Build retention
    buildDiscarder(logRotator(numToKeepStr: '10')),

    // Triggers
    pipelineTriggers([
      githubPush(),
      issueCommentTrigger('.*(?:retest|rebuild).*')
    ])
  ])

  options {
    timeout(time: 30, unit: 'MINUTES')
    timestamps()
    ansiColor('xterm')
  }

  stages {
    stage('Setup & Test') {
      agent {
        kubernetes {
          yaml """
apiVersion: v1
kind: Pod
spec:
  volumes:
  - name: hext-shared
    emptyDir: {}
  - name: docker-graph-storage
    emptyDir: {}
  containers:
  - name: setup
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
  - name: unit-tests
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
  - name: rubocop
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
"""
        }
      }
      stages {
        // ========== Stage 1: Initialize ==========
        stage('Initialize') {
          steps {
            container('setup') {
              echo "Building branch: ${env.BRANCH_NAME}"
              echo "Commit: ${env.GIT_COMMIT}"

              script {
                if (env.CHANGE_ID) {
                  echo "Pull Request: #${env.CHANGE_ID}"
                  echo "PR Title: ${env.CHANGE_TITLE}"
                  echo "PR Author: ${env.CHANGE_AUTHOR}"
                }
              }

              // Wait for Docker daemon
              sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'
              echo '✅ Docker daemon ready'

              // Clone hext repo ONCE into shared volume
              sh '''
                apk add --no-cache git python3
                cd /hext
                git clone https://github.com/duduyiq2001/hext.git .
                chmod +x hext setup.sh
                ls -la
                echo "✅ Hext CLI cloned to /hext"
              '''
            }
          }
        }

        // ========== Stage 2: Parallel CI Tests ==========
        stage('CI Tests') {
          parallel {
            // RSpec Unit Tests
            stage('RSpec Unit Tests') {
              steps {
                container('unit-tests') {
                  echo 'Running RSpec unit tests...'

                  // Wait for Docker daemon
                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'

                  // Install python3 for hext CLI
                  sh 'apk add --no-cache python3'

                  // Start containers and run tests
                  sh '''
                    cd /workspace
                    /hext/hext up
                    /hext/hext test --exclude-pattern "spec/integration/**/*_spec.rb" \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/unit.xml
                  '''
                }
              }
              post {
                always {
                  container('unit-tests') {
                    junit 'test-results/unit.xml'
                  }
                }
                cleanup {
                  container('unit-tests') {
                    sh 'cd /workspace && /hext/hext down || true'
                  }
                }
              }
            }

            // Rubocop Linting
            stage('Rubocop') {
              steps {
                container('rubocop') {
                  echo 'Running Rubocop...'

                  // Wait for Docker daemon
                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'

                  // Install python3 for hext CLI
                  sh 'apk add --no-cache python3'

                  // Start containers and run rubocop
                  sh '''
                    cd /workspace
                    /hext/hext up
                    /hext/hext shell -c "bundle exec rubocop --format simple"
                  '''
                }
              }
              post {
                cleanup {
                  container('rubocop') {
                    sh 'cd /workspace && /hext/hext down || true'
                  }
                }
              }
            }
          }
        }
      }
    }

    // ========== Integration Tests (PR Only) ==========
    stage('Integration Tests') {
      when {
        changeRequest()
      }
      agent {
        kubernetes {
          yaml """
apiVersion: v1
kind: Pod
spec:
  volumes:
  - name: hext-shared
    emptyDir: {}
  - name: docker-graph-storage
    emptyDir: {}
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
"""
        }
      }
      steps {
        container('docker') {
          echo "Running integration tests for PR-${env.CHANGE_ID}..."

          // Wait for Docker daemon
          sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'

          // Clone hext
          sh '''
            apk add --no-cache git python3
            cd /hext
            git clone https://github.com/duduyiq2001/hext.git .
            chmod +x hext
          '''

          // Run integration tests
          sh '''
            cd /workspace
            /hext/hext up
            /hext/hext test spec/integration \
              --format progress \
              --format RspecJunitFormatter \
              --out test-results/integration.xml
          '''
        }
      }
      post {
        always {
          junit 'test-results/integration.xml'
        }
        cleanup {
          container('docker') {
            sh 'cd /workspace && /hext/hext down || true'
          }
        }
      }
    }

    // ========== Build Docker Image (Main Branch) ==========
    stage('Build Docker Image') {
      when {
        branch 'main'
      }
      agent {
        kubernetes {
          yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
"""
        }
      }
      steps {
        container('docker') {
          echo 'Waiting for Docker daemon...'
          sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'

          echo 'Building production Docker image...'
          sh """
            docker build -t e_ren:\${GIT_COMMIT:0:7} .
            docker tag e_ren:\${GIT_COMMIT:0:7} e_ren:latest
            echo "✅ Image built: e_ren:\${GIT_COMMIT:0:7}"
          """

          // TODO: Push to registry when ready
          // sh "docker push your-registry/e_ren:\${GIT_COMMIT:0:7}"
        }
      }
    }
  }

  post {
    success {
      echo '✅ CI Pipeline succeeded!'
    }
    failure {
      echo '❌ CI Pipeline failed!'
    }
    cleanup {
      echo 'Pipeline cleanup complete'
    }
  }
}
