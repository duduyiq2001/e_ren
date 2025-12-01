// E-Ren CD Pipeline
// Runs on: Push to release branch
// Stages: Build & Push → Check Migrations → Deploy to EKS

pipeline {
  agent any

  triggers {
    githubPush()
  }

  environment {
    AWS_REGION = 'us-east-1'
    EKS_CLUSTER = 'e-ren-cluster'
  }

  options {
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '10'))
  }

  stages {
    // Only run on release branch
    stage('Check Branch') {
      when {
        branch 'release'
      }
      stages {
        // ========== Stage 1: Initialize ==========
        stage('Initialize') {
          steps {
            echo "🚀 CD Pipeline starting..."
            echo "Branch: ${env.BRANCH_NAME}"
            echo "Commit: ${env.GIT_COMMIT}"

            // Verify tools
            sh '''
              echo "=== Verifying tools ==="
              docker --version
              aws --version
              kubectl version --client
              helm version
            '''

            // Clone hext repo (contains helm charts + CLI)
            sh '''
              cd $WORKSPACE
              rm -rf hext
              git clone https://github.com/duduyiq2001/hext.git
              chmod +x hext/hext
              echo "✅ Hext CLI cloned"
            '''

            // Configure kubectl for EKS
            sh '''
              aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
              echo "✅ kubectl configured for EKS"
              kubectl get nodes
            '''
          }
        }

        // ========== Stage 2: Build & Push Image ==========
        stage('Build & Push') {
          steps {
            echo '🔨 Building and pushing Docker image...'

            withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
              sh '''
                echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                $WORKSPACE/hext/hext push
              '''
            }
          }
        }

        // ========== Stage 3: Check for Migrations ==========
        stage('Check Migrations') {
          steps {
            script {
              // Check if commit message contains [migrate]
              def commitMsg = sh(
                script: "git log -1 --pretty=%B",
                returnStdout: true
              ).trim()

              echo "Commit message: ${commitMsg}"

              if (commitMsg.contains('[migrate]')) {
                echo "📦 [migrate] tag found in commit message - will run migrations"
                env.HAS_MIGRATIONS = 'true'
                env.MIGRATION_REVISION = "v${env.BUILD_NUMBER}"
              } else {
                echo "✅ No [migrate] tag - skipping migrations"
                env.HAS_MIGRATIONS = 'false'
              }
            }
          }
        }

        // ========== Stage 4: Deploy to EKS ==========
        stage('Deploy') {
          steps {
            script {
              if (env.HAS_MIGRATIONS == 'true') {
                echo "🚀 Deploying with migrations (revision: ${env.MIGRATION_REVISION})..."
                sh "$WORKSPACE/hext/hext deploy --migrate ${env.MIGRATION_REVISION}"

                // Wait for migration job to complete
                echo "⏳ Waiting for migration job to complete..."
                sh "kubectl wait --for=condition=complete job/e-ren-migrate-${env.MIGRATION_REVISION} --timeout=300s"
              } else {
                echo "🚀 Deploying without migrations..."
                sh "$WORKSPACE/hext/hext deploy"
              }

            }
          }
        }

        // ========== Stage 5: Verify Deployment ==========
        stage('Verify') {
          steps {
            echo '📊 Verifying deployment...'
            sh '''
              kubectl get pods -l app=e-ren
              echo "✅ Deployment complete!"
            '''
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ CD Pipeline succeeded! Deployment complete.'
    }
    failure {
      echo '❌ CD Pipeline failed!'
    }
    aborted {
      echo '⚠️ CD Pipeline aborted'
    }
  }
}
