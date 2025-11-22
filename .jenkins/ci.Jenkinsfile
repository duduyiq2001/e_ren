// E-Ren CI Pipeline using Hext (Static agent pod)
// Runs on: Push to main branch, Pull Requests to main, PR comments (/retest)

pipeline {
  agent {
    label 'agent'
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

                // Create .env file with secrets
                withCredentials([string(credentialsId: 'google-maps-api-key', variable: 'GOOGLE_MAP_KEY')]) {
                  sh '''
                    mkdir -p /tmp/e_ren
                    cat > /tmp/e_ren/.env << EOF
GOOGLE_MAP=${GOOGLE_MAP_KEY}
RAILS_ENV=test
EOF
                    echo "✅ Environment file created at /tmp/e_ren/.env"
                  '''
                }

                // Start Rails + Postgres containers ONCE
                sh '''
                  # Create symlink so hext's ../e_ren path resolves correctly
                  ln -sf $WORKSPACE /tmp/e_ren
                  echo "✅ Symlink created: /tmp/e_ren -> $WORKSPACE"

                  cd $WORKSPACE
                  /tmp/hext/hext up
                  echo "✅ Rails and Postgres containers started"

                  echo "=== Debug: Checking all containers (including exited) ==="
                  docker ps -a

                  echo "=== Debug: Rails container logs ==="
                  docker logs e_ren_rails || echo "Failed to get logs for e_ren_rails"

                  echo "=== Debug: Waiting for Rails container to be ready ==="
                  sleep 5
                  docker ps | grep e_ren_rails && echo "✅ Rails container is running" || echo "❌ Rails container is NOT running"
                '''
              }
            }

        // ========== Stage 2: Parallel CI Tests ==========
        stage('CI Tests') {
          parallel {
            // Models Tests
            stage('Models Tests') {
              steps {
                echo 'Running Models tests...'
                sh '''
                  echo "=== Debug: Checking running containers ==="
                  docker ps
                  echo "=== Debug: Checking hext containers ==="
                  docker ps | grep -i hext || echo "No hext containers found"
                  docker ps | grep -i rails || echo "No rails containers found"
                  echo "=== Debug: Current directory ==="
                  pwd
                  echo "=== Debug: Running tests ==="
                  cd $WORKSPACE
                  /tmp/hext/hext test spec/models --format progress
                '''
              }
            }

            // Controllers Tests
            stage('Controllers Tests') {
              steps {
                echo 'Running Controllers tests...'
                sh '''
                  cd $WORKSPACE
                  /tmp/hext/hext test spec/controllers --format progress
                '''
              }
            }

            // Requests/Views/Integration Tests
            stage('Requests & Integration Tests') {
              steps {
                echo 'Running Requests, Views, and Integration tests...'
                sh '''
                  cd $WORKSPACE
                  /tmp/hext/hext test spec/requests spec/views spec/integration --format progress
                '''
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

  post {
    always {
      sh 'cd $WORKSPACE && /tmp/hext/hext down || true'
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
