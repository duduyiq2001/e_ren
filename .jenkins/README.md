# E-Ren Jenkins Pipelines

This directory contains all Jenkins pipeline definitions for the E-Ren project.

## Prerequisites

### Required: Bundle Cache PVC

The CI pipeline requires a persistent volume for caching Ruby gems between builds.

**Create the PVC:**
```bash
kubectl apply -f .jenkins/k8s/bundle-cache-pvc.yaml
```

**Verify:**
```bash
kubectl get pvc jenkins-bundle-cache -n jenkins
```

Expected output:
```
NAME                    STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
jenkins-bundle-cache    Bound    10Gi       RWO            gp2
```

---

## Pipeline Overview

### 1. CI Pipeline (`ci.Jenkinsfile`)

**Purpose:** Continuous Integration with parallel test execution and bundle caching

**Triggers:**
- Push to any branch
- Pull request opened/updated
- PR comment containing "retest" or "rebuild"

**Stages:**
1. **Initialize** - Clone Hext CLI (Docker-in-Docker orchestration tool)
2. **CI Tests** (Parallel - 4 concurrent containers)
   - Models tests (`spec/models`)
   - Controllers tests (`spec/controllers`)
   - Requests/Views/Integration tests (`spec/requests`, `spec/views`, `spec/integration`)
   - Rubocop linting
3. **Build Docker Image** (main branch only)

**Performance:**
- **First run:** ~8-10 minutes (bundle install from scratch)
- **Subsequent runs:** ~3-5 minutes (cached gems)
- **Parallelization:** 3-4x faster than sequential tests

**Bundle Caching:**
- Gems cached to PVC at `/bundle-cache`
- Shared across all parallel test containers
- Reduces build time by 2-3 minutes after first run

**GitHub Status:** Reports to GitHub as `continuous-integration/jenkins/pr-merge`

---

### 2. Deploy Pipeline (`deploy.Jenkinsfile`)

**Purpose:** Manual deployment to staging or production

**Triggers:** Manual only (parameterized build)

**Parameters:**
- `ENVIRONMENT`: staging | production
- `IMAGE_TAG`: Docker image tag (default: latest)
- `NAMESPACE`: Kubernetes namespace (default: e-ren)
- `RUN_MIGRATIONS`: Run DB migrations? (default: false)

**Stages:**
1. **Validate** - Confirm production deployments
2. **Database Migrations** (optional)
3. **Deploy** - Update Kubernetes deployment
4. **Smoke Tests** - Basic health checks

---

## Directory Structure

```
.jenkins/
├── ci.Jenkinsfile           # Main CI pipeline (with test parallelization)
├── deploy.Jenkinsfile       # Deployment pipeline
├── k8s/
│   └── bundle-cache-pvc.yaml # PVC for bundle cache
├── shared/
│   ├── pods.groovy         # Kubernetes pod templates (legacy, not used)
│   └── helpers.groovy      # Shared helper functions (legacy, not used)
└── README.md               # This file
```

---

## Jenkins Job Setup

### Job 1: `e_ren-ci` (Multibranch Pipeline)

```
Type: Multibranch Pipeline

Branch Sources:
  - GitHub
    Repository: https://github.com/duduyiq2001/e_ren
    Credentials: github-pat

Build Configuration:
  Script Path: .jenkins/ci.Jenkinsfile

Scan Triggers:
  (Controlled by Jenkinsfile properties block)
```

### Job 2: `e_ren-deploy` (Pipeline)

```
Type: Pipeline

Pipeline:
  Definition: Pipeline script from SCM

  SCM: Git
    Repository URL: https://github.com/duduyiq2001/e_ren
    Branch: main
    Script Path: .jenkins/deploy.Jenkinsfile

Parameters:
  (Defined in Jenkinsfile)

Build Triggers:
  None (manual only)
```

---

## Shared Resources

### Pod Templates (`shared/pods.groovy`)

Reusable Kubernetes pod definitions:

- `rubyPod()` - Ruby + Postgres (for tests with DB)
- `rubyOnlyPod()` - Ruby only (for linting)
- `dockerPod()` - Docker-in-Docker (for image builds)
- `kubectlPod()` - Kubectl (for deployments)

**Usage:**
```groovy
def pods = load '.jenkins/shared/pods.groovy'

agent {
  kubernetes {
    yaml pods.rubyPod()
  }
}
```

### Helper Functions (`shared/helpers.groovy`)

Common operations:

- `waitForPostgres(timeout)` - Wait for Postgres to be ready
- `setupDatabase()` - Create and load test DB schema
- `installBundler()` - Install gems with caching
- `runRspec(pattern, outputFile)` - Run RSpec with JUnit output
- `runRubocop()` - Run Rubocop linter
- `notifyGitHub(context, status, description)` - Send GitHub status

**Usage:**
```groovy
def helpers = load '.jenkins/shared/helpers.groovy'

helpers.installBundler()
helpers.waitForPostgres()
helpers.setupDatabase()
helpers.runRspec()
```

---

## Running Pipelines

### CI Pipeline

Runs automatically on:
- Push to any branch
- PR creation/update
- Comment `/retest` on PR

**Manual trigger:**
1. Go to Jenkins → `e_ren-ci`
2. Select branch
3. Click "Build Now"

### Deploy Pipeline

**To deploy:**

1. Go to Jenkins → `e_ren-deploy`
2. Click "Build with Parameters"
3. Configure:
   - Environment: `staging` or `production`
   - Image Tag: e.g., `abc1234` (git commit SHA) or `latest`
   - Run Migrations: Check if needed
4. Click "Build"
5. For production: Confirm the deployment prompt

---

## Environment Variables

Available in all pipelines:

### Git Variables
- `GIT_COMMIT` - Full commit SHA
- `GIT_BRANCH` - Branch name
- `BRANCH_NAME` - Short branch name

### PR Variables (when building PR)
- `CHANGE_ID` - PR number
- `CHANGE_URL` - PR URL
- `CHANGE_TITLE` - PR title
- `CHANGE_AUTHOR` - PR author
- `CHANGE_TARGET` - Target branch

### Jenkins Variables
- `BUILD_NUMBER` - Build number
- `BUILD_URL` - Link to build
- `WORKSPACE` - Workspace path

---

## Customization

### Adding a New Pipeline

1. Create `.jenkins/my-pipeline.Jenkinsfile`
2. Load shared resources:
   ```groovy
   def pods = load '.jenkins/shared/pods.groovy'
   def helpers = load '.jenkins/shared/helpers.groovy'
   ```
3. Create Jenkins job pointing to new Jenkinsfile

### Adding a New Pod Template

Edit `.jenkins/shared/pods.groovy`:

```groovy
def myCustomPod() {
  return """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: my-tool
    image: my-tool:latest
    command: ['sleep']
    args: ['infinity']
"""
}
```

### Adding a New Helper Function

Edit `.jenkins/shared/helpers.groovy`:

```groovy
def myHelper(String arg) {
  sh "echo ${arg}"
}
```

---

## Troubleshooting

### CI Pipeline Not Triggering

1. Check GitHub webhook:
   - Repo → Settings → Webhooks → Recent Deliveries
   - Should see 200 responses

2. Check Jenkins job scan:
   - Job → Scan Multibranch Pipeline Now

3. Verify credentials:
   - Manage Jenkins → Credentials → `github-pat`

### Tests Failing on Postgres Connection

- Increase `waitForPostgres()` timeout
- Check pod logs: `kubectl logs <pod-name> -c postgres`

### Deploy Pipeline Fails

- Verify `kubectl` has permissions (ServiceAccount)
- Check namespace exists
- Verify image exists in registry

---

## Best Practices

1. **Always use shared resources** - Don't duplicate pod templates
2. **Keep Jenkinsfiles DRY** - Extract common logic to helpers
3. **Test locally first** - Use Docker Compose to test before pushing
4. **Use semantic versioning** - Tag releases with `v1.2.3`
5. **Production deployments** - Always review changes before confirming
6. **Monitor builds** - Check Jenkins regularly for failures

---

## Links

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [GitHub Branch Source Plugin](https://plugins.jenkins.io/github-branch-source/)
