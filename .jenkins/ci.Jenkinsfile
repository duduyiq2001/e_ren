// E-Ren CI Pipeline using Hext (Static agent pod)
// Runs on: Push to main branch, Pull Requests to main, PR comments (/retest)

pipeline {
  agent any

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

                // Clone hext repo and modify docker-compose for workspace
                sh '''
                  cd $WORKSPACE
                  rm -rf hext
                  git clone https://github.com/duduyiq2001/hext.git
                  cd hext
                  chmod +x hext setup.sh

                  # Modify docker-compose.yml to use workspace directory
                  sed -i 's|../e_ren:/rails|..:/rails|g' docker-compose.yml
                  sed -i 's|../e_ren/.env|../.env|g' docker-compose.yml

                  # Fix container name check in hext script (looks for hext_rails but compose creates e_ren_rails)
                  sed -i 's|CONTAINER_NAME = "hext_rails"|CONTAINER_NAME = "e_ren_rails"|g' hext

                  echo "✅ Hext CLI cloned and configured for workspace"

                  # Verify the changes
                  echo "=== Docker Compose configuration ==="
                  grep -E "(env_file:|volumes:)" -A 1 docker-compose.yml | grep -E "(env_file|e_ren|\\.\\.|rails)"
                  echo "=== Container name in hext script ==="
                  grep "CONTAINER_NAME" hext | head -1
                '''

                // Create .env file with secrets in workspace
                withCredentials([string(credentialsId: 'google-maps-api-key', variable: 'GOOGLE_MAP_KEY')]) {
                  sh '''
                    cat > $WORKSPACE/.env << EOF
GOOGLE_MAP=${GOOGLE_MAP_KEY}
RAILS_ENV=test
EOF
                    echo "✅ Environment file created at $WORKSPACE/.env"
                  '''
                }

                sh '''
                  cd $WORKSPACE

                  # Remove DATABASE_URL from docker-compose so RAILS_ENV controls db selection
                  sed -i '/DATABASE_URL/d' hext/docker-compose.yml
                  echo "✅ Removed DATABASE_URL from docker-compose (will use RAILS_ENV instead)"

                  ./hext/hext up
                  echo "✅ Rails and Postgres containers started"

                  echo "=== Installing gems with bundle install ==="
                  docker exec e_ren_rails sh -c "cd /rails && bundle install"

                  echo "=== Setting up test database ==="
                  docker exec e_ren_rails sh -c "cd /rails && RAILS_ENV=test bin/rails db:drop db:create db:schema:load"

                  echo "=== Verifying test database ==="
                  docker exec e_ren_rails sh -c "cd /rails && RAILS_ENV=test bin/rails runner 'puts \"Test DB: #{ActiveRecord::Base.connection.current_database}\"'"

                  echo "=== Verifying installation ==="
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
                  cd $WORKSPACE
                  $WORKSPACE/hext/hext test spec/models --format progress
                '''
              }
            }

            // Controllers Tests
            stage('Controllers Tests') {
              steps {
                echo 'Running Controllers tests...'
                sh '''
                  cd $WORKSPACE
                  $WORKSPACE/hext/hext test spec/controllers --format progress
                '''
              }
            }

            // Requests/Views/Integration Tests
            stage('Requests & Integration Tests') {
              steps {
                echo 'Running Requests, Views, and Integration tests...'
                sh '''
                  cd $WORKSPACE
                  $WORKSPACE/hext/hext test spec/requests spec/views spec/integration --format progress
                '''
              }
            }
          }
        }

      }
    }
  }

  post {
    always {
      sh 'cd $WORKSPACE && ./hext/hext down || true'
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
