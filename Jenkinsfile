pipeline {
    agent {
        kubernetes {
            label 'e-ren-builder'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  nodeSelector:
    role: agent
  containers:
  - name: ruby
    image: ruby:3.2
    command:
    - cat
    tty: true
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
"""
        }
    }
        triggers {
        // Poll SCM every 5 minutes.
        pollSCM('H/5 * * * *')
    }
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code...'
                checkout scm
            }
        }
        stage('Environment Info') {
            steps {
                container('ruby') {
                    sh '''
                        echo "=== Ruby Version ==="
                        ruby --version
                        echo "=== Bundler Version ==="
                        bundle --version || gem install bundler --no-document && bundle --version
                        echo "=== Current Directory ==="
                        pwd
                        ls -la
                    '''
                }
            }
        }
        stage('Install Dependencies') {
            steps {
                container('ruby') {
                    sh '''
                        echo "Installing Ruby gems..."
                        bundle config set --local path 'vendor/bundle' || true
                        bundle install --jobs=4 --retry=3
                    '''
                }
            }
        }
        stage('Run Tests') {
            steps {
                container('ruby') {
                    sh '''
                        echo "Running RSpec tests..."
                        bundle exec rspec --format documentation || true
                    '''
                }
            }
        }
        stage('Lint') {
            steps {
                container('ruby') {
                    sh '''
                        echo "Running RuboCop..."
                        bundle exec rubocop || true
                    '''
                }
            }
        }
    }
    post {
        success {
            echo '✅ Pipeline succeeded!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            echo "Build #${env.BUILD_NUMBER} completed"
            echo "Branch: ${env.GIT_BRANCH}"
            echo "Commit: ${env.GIT_COMMIT}"
        }
    }
}