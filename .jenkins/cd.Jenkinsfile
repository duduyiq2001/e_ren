// E-Ren CD Pipeline - Continuous Deployment
// Runs on: Push to 'release' branch (automatic deployment to production)

pipeline {
  agent any

  triggers {
    githubPush()
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    DOCKER_REGISTRY = 'your-registry.com'
    DEPLOYMENT_NAME = 'e-ren'
    PRODUCTION_NAMESPACE = 'e-ren-prod'
  }

  stages {
    // Only run on release branch
    stage('Check Branch') {
      when {
        branch 'release'
      }
      stages {
        // ========== Stage 1: Build & Push Docker Image ==========
        stage('Build Production Image') {
          steps {
            echo 'Building production Docker image...'

            script {
              // Generate semantic version tag from commit
              def imageTag = sh(
                script: "git describe --tags --always --abbrev=7",
                returnStdout: true
              ).trim()

              env.IMAGE_TAG = imageTag

              echo "Building image: ${env.DOCKER_REGISTRY}/e_ren:${imageTag}"

              sh """
                docker build -t ${env.DOCKER_REGISTRY}/e_ren:${imageTag} .
                docker tag ${env.DOCKER_REGISTRY}/e_ren:${imageTag} ${env.DOCKER_REGISTRY}/e_ren:latest
              """

              // TODO: Add Docker registry login
              // sh "docker login ${env.DOCKER_REGISTRY}"

              // Push to registry
              sh """
                echo "Would push: ${env.DOCKER_REGISTRY}/e_ren:${imageTag}"
                # docker push ${env.DOCKER_REGISTRY}/e_ren:${imageTag}
                # docker push ${env.DOCKER_REGISTRY}/e_ren:latest
              """

              echo "✅ Image built and pushed: ${imageTag}"
            }
          }
        }

        // ========== Stage 2: Deploy to Production ==========
        stage('Deploy to Production') {
          steps {
            echo "============================================="
            echo "🚀 DEPLOYING TO PRODUCTION"
            echo "Image: ${env.DOCKER_REGISTRY}/e_ren:${env.IMAGE_TAG}"
            echo "Namespace: ${env.PRODUCTION_NAMESPACE}"
            echo "============================================="

            // Update deployment
            sh """
              kubectl set image deployment/${env.DEPLOYMENT_NAME} \
                ${env.DEPLOYMENT_NAME}=${env.DOCKER_REGISTRY}/e_ren:${env.IMAGE_TAG} \
                --namespace=${env.PRODUCTION_NAMESPACE} \
                --record

              # Wait for rollout to complete
              kubectl rollout status deployment/${env.DEPLOYMENT_NAME} \
                --namespace=${env.PRODUCTION_NAMESPACE} \
                --timeout=10m
            """

            echo "✅ Deployment successful!"

            // Show deployment status
            sh """
              echo ""
              echo "Current deployment status:"
              kubectl get deployment ${env.DEPLOYMENT_NAME} \
                --namespace=${env.PRODUCTION_NAMESPACE}

              echo ""
              echo "Pod status:"
              kubectl get pods -l app=${env.DEPLOYMENT_NAME} \
                --namespace=${env.PRODUCTION_NAMESPACE}
            """
          }
        }
      }
    }
  }

  post {
    success {
      echo '✅ CD Pipeline succeeded - Production deployed!'
    }
    failure {
      echo '❌ CD Pipeline failed - Production deployment failed!'
      // TODO: Add alerting (Slack, PagerDuty, etc.)
    }
    aborted {
      echo '⚠️ CD Pipeline skipped (not release branch)'
    }
    cleanup {
      echo 'Pipeline cleanup complete'
    }
  }
}
