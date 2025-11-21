// Shared Kubernetes Pod Templates for Jenkins Pipelines

def rubyPod() {
  return """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
    app: e_ren
spec:
  containers:
  - name: ruby
    image: ruby:3.2
    command: ['sleep']
    args: ['infinity']
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    volumeMounts:
    - name: bundle-cache
      mountPath: /usr/local/bundle
  - name: postgres
    image: postgres:15-alpine
    env:
    - name: POSTGRES_USER
      value: postgres
    - name: POSTGRES_PASSWORD
      value: password
    - name: POSTGRES_DB
      value: e_ren_test
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  volumes:
  - name: bundle-cache
    emptyDir: {}
"""
}

def rubyOnlyPod() {
  return """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
    app: e_ren
spec:
  containers:
  - name: ruby
    image: ruby:3.2
    command: ['sleep']
    args: ['infinity']
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    volumeMounts:
    - name: bundle-cache
      mountPath: /usr/local/bundle
  volumes:
  - name: bundle-cache
    emptyDir: {}
"""
}

def dockerPod() {
  return """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
    app: e_ren
spec:
  containers:
  - name: docker
    image: docker:24-dind
    securityContext:
      privileged: true
    resources:
      requests:
        memory: "1Gi"
        cpu: "1000m"
      limits:
        memory: "2Gi"
        cpu: "2000m"
    volumeMounts:
    - name: docker-cache
      mountPath: /var/lib/docker
  volumes:
  - name: docker-cache
    emptyDir: {}
"""
}

def kubectlPod() {
  return """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
    app: e_ren
spec:
  serviceAccountName: jenkins
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ['sleep']
    args: ['infinity']
    resources:
      requests:
        memory: "128Mi"
        cpu: "100m"
      limits:
        memory: "256Mi"
        cpu: "200m"
"""
}

return this
