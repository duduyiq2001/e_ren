// E-Ren CI Pipeline using Hext (Docker-in-Docker with Test Parallelization)
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
  - name: bundle-cache
    persistentVolumeClaim:
      claimName: jenkins-bundle-cache
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
    - name: bundle-cache
      mountPath: /bundle-cache
  - name: test-models
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
    - name: bundle-cache
      mountPath: /bundle-cache
  - name: test-controllers
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
    - name: bundle-cache
      mountPath: /bundle-cache
  - name: test-requests
    image: docker:24-dind
    securityContext:
      privileged: true
    command: ['dockerd-entrypoint.sh']
    volumeMounts:
    - name: hext-shared
      mountPath: /hext
    - name: docker-graph-storage
      mountPath: /var/lib/docker
    - name: bundle-cache
      mountPath: /bundle-cache
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
    - name: bundle-cache
      mountPath: /bundle-cache
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

              // Configure hext to use bundle cache
              sh '''
                # Update docker-compose.yml to use bundle cache volume
                cd /hext
                sed -i 's|bundle_cache:|bundle_cache:\\n      driver_opts:\\n        type: none\\n        o: bind\\n        device: /bundle-cache|g' docker-compose.yml || true
                echo "✅ Bundle cache configured"
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
                container('test-models') {
                  echo 'Running Models tests...'

                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'
                  sh 'apk add --no-cache python3'

                  sh '''
                    cd /workspace
                    /hext/hext up
                    /hext/hext test spec/models \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/models.xml
                  '''
                }
              }
              post {
                always {
                  container('test-models') {
                    junit 'test-results/models.xml'
                  }
                }
                cleanup {
                  container('test-models') {
                    sh 'cd /workspace && /hext/hext down || true'
                  }
                }
              }
            }

            // Controllers Tests
            stage('Controllers Tests') {
              steps {
                container('test-controllers') {
                  echo 'Running Controllers tests...'

                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'
                  sh 'apk add --no-cache python3'

                  sh '''
                    cd /workspace
                    /hext/hext up
                    /hext/hext test spec/controllers \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/controllers.xml
                  '''
                }
              }
              post {
                always {
                  container('test-controllers') {
                    junit 'test-results/controllers.xml'
                  }
                }
                cleanup {
                  container('test-controllers') {
                    sh 'cd /workspace && /hext/hext down || true'
                  }
                }
              }
            }

            // Requests/Views/Integration Tests
            stage('Requests & Integration Tests') {
              steps {
                container('test-requests') {
                  echo 'Running Requests, Views, and Integration tests...'

                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'
                  sh 'apk add --no-cache python3'

                  sh '''
                    cd /workspace
                    /hext/hext up
                    /hext/hext test spec/requests spec/views spec/integration \
                      --format progress \
                      --format RspecJunitFormatter \
                      --out test-results/requests.xml
                  '''
                }
              }
              post {
                always {
                  container('test-requests') {
                    junit 'test-results/requests.xml'
                  }
                }
                cleanup {
                  container('test-requests') {
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

                  sh 'timeout 30 sh -c "until docker info >/dev/null 2>&1; do sleep 1; done"'
                  sh 'apk add --no-cache python3'

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
