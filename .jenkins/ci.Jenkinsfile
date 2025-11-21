// E-Ren CI Pipeline using Hext (Custom agent with test parallelization)
// Runs on: Push to main branch, Pull Requests to main, PR comments (/retest)

pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: agent
    image: duyiqun/ere:jenkins-agent
    command: ['sleep']
    args: ['99d']
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
      type: Socket
"""
    }
  }

  triggers {
    githubPush()
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  stages {
    // Skip entire pipeline if not main branch or PR to main
    stage('Check Branch') {
      when {
        anyOf {
          branch 'main'
          changeRequest target: 'main'
        }
      }
      stages {
        // ========== Stage 1: Initialize ==========
        stage('Initialize') {
          steps {
            container('agent') {
              echo "Building branch: ${env.BRANCH_NAME}"
              echo "Commit: ${env.GIT_COMMIT}"

              script {
                if (env.CHANGE_ID) {
                  echo "Pull Request: #${env.CHANGE_ID}"
                  echo "PR Title: ${env.CHANGE_TITLE}"
                  echo "PR Author: ${env.CHANGE_AUTHOR}"
                  echo "PR Target: ${env.CHANGE_TARGET}"
                }
              }

              // Verify tools
              sh 'python --version && docker --version && git --version'

              // Clone hext repo
              sh '''
                cd /tmp
                rm -rf hext
                git clone https://github.com/duduyiq2001/hext.git
                cd hext
                chmod +x hext setup.sh
                echo "✅ Hext CLI cloned"
              '''

              // Start Rails + Postgres containers ONCE
              sh '''
                cd $WORKSPACE
                /tmp/hext/hext up
                echo "✅ Rails and Postgres containers started"
              '''
            }
          }
        }

        // ========== Stage 2: Parallel CI Tests ==========
        stage('CI Tests') {
          parallel {
            // Models Tests
            stage('Models Tests') {
              steps {
                container('agent') {
                  echo 'Running Models tests...'
                  sh '''
                    cd $WORKSPACE
                    /tmp/hext/hext test spec/models \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/models.xml
                  '''
                }
              }
              post {
                always {
                  junit 'test-results/models.xml'
                }
              }
            }

            // Controllers Tests
            stage('Controllers Tests') {
              steps {
                container('agent') {
                  echo 'Running Controllers tests...'
                  sh '''
                    cd $WORKSPACE
                    /tmp/hext/hext test spec/controllers \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/controllers.xml
                  '''
                }
              }
              post {
                always {
                  junit 'test-results/controllers.xml'
                }
              }
            }

            // Requests/Views/Integration Tests
            stage('Requests & Integration Tests') {
              steps {
                container('agent') {
                  echo 'Running Requests, Views, and Integration tests...'
                  sh '''
                    cd $WORKSPACE
                    /tmp/hext/hext test spec/requests spec/views spec/integration \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/requests.xml
                  '''
                }
              }
              post {
                always {
                  junit 'test-results/requests.xml'
                }
              }
            }

            // Rubocop Linting
            stage('Rubocop') {
              steps {
                container('agent') {
                  echo 'Running Rubocop...'
                  sh '''
                    cd $WORKSPACE
                    /tmp/hext/hext shell -c "bundle exec rubocop --format simple"
                  '''
                }
              }
            }
          }
        }

        // ========== Build Docker Image (Main Branch Only) ==========
        stage('Build Docker Image') {
          when {
            branch 'main'
          }
          steps {
            container('agent') {
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
    }
  }

  post {
    always {
      script {
        container('agent') {
          sh 'cd $WORKSPACE && /tmp/hext/hext down || true'
        }
      }
    }
    success {
      echo '✅ CI Pipeline succeeded!'
    }
    failure {
      echo '❌ CI Pipeline failed!'
    }
    aborted {
      echo '⚠️ CI Pipeline skipped (not main branch or PR to main)'
    }
    cleanup {
      echo 'Pipeline cleanup complete'
    }
  }
}
