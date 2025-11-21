# E-Ren Jenkins Pipelines

This directory contains all Jenkins pipeline definitions for the E-Ren project.

## Prerequisites

### Required: Jenkins Agent with Docker

Jenkins agents must have Docker installed and accessible. The pipelines use `agent any` and run Docker commands directly on the agent node.

---

## Pipeline Overview

### 1. CI Pipeline (`ci.Jenkinsfile`)

**Purpose:** Continuous Integration with parallel test execution and bundle caching

**Triggers:**
- Push to any branch
- Pull request opened/updated
- PR comment containing "retest" or "rebuild"

**Stages:**
1. **Initialize** - Clone Hext CLI, start Rails + Postgres containers once
2. **CI Tests** (Parallel - 4 concurrent test suites)
   - Models tests (`spec/models`)
   - Controllers tests (`spec/controllers`)
   - Requests/Views/Integration tests (`spec/requests`, `spec/views`, `spec/integration`)
   - Rubocop linting
3. **Build Docker Image** (main branch only)

**Architecture:**
- Single `hext up` starts Rails + Postgres containers
- All parallel test stages reuse the same containers
- Direct Docker socket access (no Docker-in-Docker)

**GitHub Status:** Reports to GitHub as `continuous-integration/jenkins/pr-merge`

---

### 2. CD Pipeline (`cd.Jenkinsfile`)

**Purpose:** Continuous Deployment to production

**Triggers:**
- Push to `release` branch (automatic)

**Stages:**
1. **Build Production Image** - Build and push Docker image with semantic version tag
2. **Deploy to Production** - Update Kubernetes deployment

**GitHub Status:** Reports to GitHub as `continuous-integration/jenkins/branch`

**Workflow:**
```
main branch → PR merged → create release branch → automatic production deploy
```

---

### 3. Deploy Pipeline (`deploy.Jenkinsfile`)

**Purpose:** Manual deployment to staging or production

**Triggers:** Manual only (not automatic)

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
├── ci.Jenkinsfile           # CI: Tests on main branch & PRs
├── cd.Jenkinsfile           # CD: Auto-deploy on release branch
├── deploy.Jenkinsfile       # Manual deployment tool
├── k8s/
│   └── bundle-cache-pvc.yaml # Legacy: PVC for bundle cache (not used)
├── shared/
│   ├── pods.groovy         # Legacy: Kubernetes pod templates (not used)
│   └── helpers.groovy      # Legacy: Shared helper functions (not used)
└── README.md               # This file
```

---

## Pipeline Trigger Summary

| Pipeline | Automatic Triggers | Manual Trigger |
|----------|-------------------|----------------|
| **CI** | Push to `main`, PR to `main`, `/retest` comment | ✅ Yes |
| **CD** | Push to `release` branch | ✅ Yes |
| **Deploy** | None | ✅ Manual only |

---

## Jenkins Job Setup

### Job 1: `e_ren-ci` (Multibranch Pipeline)

**Runs:** CI tests on `main` branch and PRs to `main`

```
Type: Multibranch Pipeline

Branch Sources:
  - GitHub
    Repository: https://github.com/duduyiq2001/e_ren
    Credentials: github-pat

  Behaviors:
    - Discover branches: main only
    - Discover PRs: from origin (targeting main)

Build Configuration:
  Script Path: .jenkins/ci.Jenkinsfile

Scan Triggers:
  (Controlled by Jenkinsfile properties block)
```

### Job 2: `e_ren-cd` (Multibranch Pipeline)

**Runs:** Automatic production deployment on `release` branch

```
Type: Multibranch Pipeline

Branch Sources:
  - GitHub
    Repository: https://github.com/duduyiq2001/e_ren
    Credentials: github-pat

  Behaviors:
    - Discover branches: release only

Build Configuration:
  Script Path: .jenkins/cd.Jenkinsfile

Scan Triggers:
  (Controlled by Jenkinsfile properties block)
```

### Job 3: `e_ren-deploy` (Pipeline)

**Runs:** Manual deployments to staging or production

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

## Troubleshooting

### CI Pipeline Not Triggering

1. Check GitHub webhook:
   - Repo → Settings → Webhooks → Recent Deliveries
   - Should see 200 responses

2. Check Jenkins job scan:
   - Job → Scan Multibranch Pipeline Now

3. Verify credentials:
   - Manage Jenkins → Credentials → `github-pat`

### Tests Failing

- Check Docker is running on Jenkins agent
- Verify hext repo is accessible
- Check Docker logs: `docker logs <container-name>`

### Deploy Pipeline Fails

- Verify `kubectl` is installed on Jenkins agent
- Check namespace exists
- Verify image exists in registry

---

## Best Practices

1. **Test locally first** - Use `hext` CLI to test before pushing
2. **Use semantic versioning** - Tag releases with `v1.2.3`
3. **Production deployments** - Always review changes before merging to release branch
4. **Monitor builds** - Check Jenkins regularly for failures

---

## Links

- [Jenkins Documentation](https://www.jenkins.io/doc/)
- [Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)
- [GitHub Branch Source Plugin](https://plugins.jenkins.io/github-branch-source/)
