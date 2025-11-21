// E-Ren Deployment Pipeline
// Manual trigger only - deploys to staging or production

def pods

pipeline {
  agent none

  parameters {
    choice(
      name: 'ENVIRONMENT',
      choices: ['staging', 'production'],
      description: 'Target deployment environment'
    )
    string(
      name: 'IMAGE_TAG',
      defaultValue: 'latest',
      description: 'Docker image tag to deploy (e.g., "latest" or git commit SHA)'
    )
    string(
      name: 'NAMESPACE',
      defaultValue: 'e-ren',
      description: 'Kubernetes namespace'
    )
    booleanParam(
      name: 'RUN_MIGRATIONS',
      defaultValue: false,
      description: 'Run database migrations before deployment?'
    )
  }

  options {
    timeout(time: 20, unit: 'MINUTES')
    timestamps()
    ansiColor('xterm')
  }

  environment {
    DOCKER_REGISTRY = 'your-registry.com'
    DEPLOYMENT_NAME = 'e-ren'
  }

  stages {
    stage('Initialize') {
      steps {
        script {
          pods = load '.jenkins/shared/pods.groovy'

          echo "==================================================="
          echo "Deployment Configuration:"
          echo "  Environment: ${params.ENVIRONMENT}"
          echo "  Image Tag: ${params.IMAGE_TAG}"
          echo "  Namespace: ${params.NAMESPACE}"
          echo "  Run Migrations: ${params.RUN_MIGRATIONS}"
          echo "==================================================="
        }
      }
    }

    stage('Validate') {
      steps {
        script {
          // Ensure image tag is not empty
          if (!params.IMAGE_TAG || params.IMAGE_TAG.trim() == '') {
            error("IMAGE_TAG cannot be empty!")
          }

          // Production requires explicit confirmation
          if (params.ENVIRONMENT == 'production') {
            def deployMsg = """
🚨 PRODUCTION DEPLOYMENT 🚨

Environment: PRODUCTION
Image Tag: ${params.IMAGE_TAG}
Namespace: ${params.NAMESPACE}
Migrations: ${params.RUN_MIGRATIONS ? 'YES' : 'NO'}

Are you sure you want to proceed?
"""
            timeout(time: 15, unit: 'MINUTES') {
              input message: deployMsg, ok: 'Deploy to Production'
            }
          }
        }
      }
    }

    stage('Database Migrations') {
      when {
        expression { params.RUN_MIGRATIONS == true }
      }
      agent {
        kubernetes {
          yaml pods.kubectlPod()
        }
      }
      steps {
        container('kubectl') {
          echo 'Running database migrations...'
          sh """
            kubectl run rails-migrate-\${BUILD_NUMBER} \\
              --image=${DOCKER_REGISTRY}/e_ren:${params.IMAGE_TAG} \\
              --namespace=${params.NAMESPACE} \\
              --restart=Never \\
              --env="RAILS_ENV=${params.ENVIRONMENT}" \\
              --command -- bundle exec rails db:migrate

            # Wait for migration to complete
            kubectl wait --for=condition=complete \\
              --timeout=5m \\
              job/rails-migrate-\${BUILD_NUMBER} \\
              --namespace=${params.NAMESPACE}

            # Show migration logs
            kubectl logs job/rails-migrate-\${BUILD_NUMBER} \\
              --namespace=${params.NAMESPACE}

            # Cleanup migration job
            kubectl delete job rails-migrate-\${BUILD_NUMBER} \\
              --namespace=${params.NAMESPACE}
          """
        }
      }
    }

    stage('Deploy') {
      agent {
        kubernetes {
          yaml pods.kubectlPod()
        }
      }
      steps {
        container('kubectl') {
          echo "Deploying to ${params.ENVIRONMENT}..."

          script {
            // Update deployment image
            sh """
              kubectl set image deployment/${DEPLOYMENT_NAME} \\
                ${DEPLOYMENT_NAME}=${DOCKER_REGISTRY}/e_ren:${params.IMAGE_TAG} \\
                --namespace=${params.NAMESPACE} \\
                --record

              # Wait for rollout to complete
              kubectl rollout status deployment/${DEPLOYMENT_NAME} \\
                --namespace=${params.NAMESPACE} \\
                --timeout=5m
            """

            echo "✅ Deployment successful!"

            // Get deployment info
            sh """
              echo ""
              echo "Current deployment status:"
              kubectl get deployment ${DEPLOYMENT_NAME} \\
                --namespace=${params.NAMESPACE}

              echo ""
              echo "Pod status:"
              kubectl get pods -l app=${DEPLOYMENT_NAME} \\
                --namespace=${params.NAMESPACE}
            """
          }
        }
      }
    }

    stage('Smoke Tests') {
      agent {
        kubernetes {
          yaml pods.kubectlPod()
        }
      }
      steps {
        container('kubectl') {
          echo 'Running smoke tests...'

          sh """
            # Get service endpoint
            SERVICE_URL=\$(kubectl get service ${DEPLOYMENT_NAME} \\
              --namespace=${params.NAMESPACE} \\
              -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

            echo "Service URL: \${SERVICE_URL}"

            # Simple health check
            # TODO: Replace with actual health endpoint
            echo "Smoke tests would run here"
            # curl -f http://\${SERVICE_URL}/health || exit 1
          """
        }
      }
    }
  }

  post {
    success {
      echo """
✅ Deployment Successful!

Environment: ${params.ENVIRONMENT}
Image: ${DOCKER_REGISTRY}/e_ren:${params.IMAGE_TAG}
Namespace: ${params.NAMESPACE}
"""
    }
    failure {
      echo """
❌ Deployment Failed!

Environment: ${params.ENVIRONMENT}
Check logs above for details.
"""
    }
    cleanup {
      echo 'Cleaning up...'
    }
  }
}
