# E-Ren Production Architecture

## Overview
Production deployment architecture for E-Ren at WashU, designed to handle 500-1000 students for 1-month pilot. Stack replicates enterprise production patterns with managed AWS services.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INTERNET (Users)                          │
└────────────────────────────────┬────────────────────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   Route 53 (DNS)        │
                    │   eren.washu.edu        │
                    └────────────┬────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │   CloudFront CDN        │
                    │   (Assets, Images)      │
                    │   FREE (< 1TB)          │
                    └────────────┬────────────┘
                                 │
┌────────────────────────────────▼────────────────────────────────────┐
│                          AWS VPC (us-east-1)                        │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │     Application Load Balancer (ALB)                          │ │
│  │     Auto-created by AWS Load Balancer Controller             │ │
│  │     $16/month + $0.008/LCU-hour                              │ │
│  └─────────────────────────┬────────────────────────────────────┘ │
│                            │                                       │
│  ┌─────────────────────────▼───────────────────────────────────┐  │
│  │                  EKS Cluster (Kubernetes)                    │  │
│  │                  Control Plane: $72/month                    │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  AWS Load Balancer Controller (System Pod)             │ │  │
│  │  │  - Watches Ingress resources                           │ │  │
│  │  │  - Auto-creates/updates ALB via AWS API                │ │  │
│  │  └────────────────────────────────────────────────────────┘ │  │
│  │                                                              │  │
│  │  ┌────────────────────────────────────────────────────────┐ │  │
│  │  │  Ingress Resource (eren-ingress)                       │ │  │
│  │  │  - Host: eren.washu.edu                                │ │  │
│  │  │  - SSL: ACM certificate                                │ │  │
│  │  │  - Routes to eren-service                              │ │  │
│  │  └─────────────────────┬──────────────────────────────────┘ │  │
│  │                        │                                     │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  Application Node Group (2x t3.medium)               │   │  │
│  │  │  $60/month                                           │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌────────────────────────────────────────────────┐ │   │  │
│  │  │  │  Datadog Agent (DaemonSet - 1 per node)        │ │   │  │
│  │  │  │  - Monitors all pods on this node              │ │   │  │
│  │  │  └────────────────────────────────────────────────┘ │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │  │
│  │  │  │  Rails Pod  │  │  Rails Pod  │  │  Rails Pod  │ │   │  │
│  │  │  │  ┌────────┐ │  │  ┌────────┐ │  │  ┌────────┐ │ │   │  │
│  │  │  │  │ Rails  │ │  │  │ Rails  │ │  │  │ Rails  │ │ │   │  │
│  │  │  │  │ Puma   │ │  │  │ Puma   │ │  │  │ Puma   │ │ │   │  │
│  │  │  │  │+Sentry │ │  │  │+Sentry │ │  │  │+Sentry │ │ │   │  │
│  │  │  │  └────┬───┘ │  │  └────┬───┘ │  │  └────┬───┘ │ │   │  │
│  │  │  │  ┌────▼───┐ │  │  ┌────▼───┐ │  │  ┌────▼───┐ │ │   │  │
│  │  │  │  │PgBncr  │ │  │  │PgBncr  │ │  │  │PgBncr  │ │ │   │  │
│  │  │  │  │sidecar │ │  │  │sidecar │ │  │  │sidecar │ │ │   │  │
│  │  │  │  └────┬───┘ │  │  └────┬───┘ │  │  └────┬───┘ │ │   │  │
│  │  │  └───────┼─────┘  └───────┼─────┘  └───────┼─────┘ │   │  │
│  │  │          │                 │                 │       │   │  │
│  │  │  ┌───────▼─────────────────▼─────────────────▼────┐ │   │  │
│  │  │  │         Sidekiq Workers (async jobs)           │ │   │  │
│  │  │  │         - Email notifications                  │ │   │  │
│  │  │  │         - E-score updates                      │ │   │  │
│  │  │  │         - Geocoding requests                   │ │   │  │
│  │  │  └────────────────────┬───────────────────────────┘ │   │  │
│  │  └────────────────────────┼──────────────────────────────┘   │  │
│  │                            │                                  │  │
│  │  ┌──────────────────────────────────────────────────────┐   │  │
│  │  │  Jenkins Node Group (1x t3.medium)                   │   │  │
│  │  │  $30/month                                           │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌────────────────────────────────────────────────┐ │   │  │
│  │  │  │  Datadog Agent (DaemonSet - 1 per node)        │ │   │  │
│  │  │  │  - Monitors Jenkins controller and agents      │ │   │  │
│  │  │  └────────────────────────────────────────────────┘ │   │  │
│  │  │                                                      │   │  │
│  │  │  ┌────────────────────────────────────────────────┐ │   │  │
│  │  │  │  Jenkins Controller (StatefulSet)              │ │   │  │
│  │  │  │  - Resources: 1 CPU, 2GB RAM                  │ │   │  │
│  │  │  │  - Storage: 20GB PersistentVolume ($2/mo)     │ │   │  │
│  │  │  │  - Web UI: jenkins.internal.eren.washu.edu    │ │   │  │
│  │  │  └────────────────────┬───────────────────────────┘ │   │  │
│  │  │                       │                             │   │  │
│  │  │                       │ (spawns on-demand)          │   │  │
│  │  │                       ▼                             │   │  │
│  │  │  ┌────────────────────────────────────────────────┐ │   │  │
│  │  │  │  Dynamic Jenkins Agent Pods (Ephemeral)       │ │   │  │
│  │  │  │  ┌──────────────┐  ┌──────────────┐           │ │   │  │
│  │  │  │  │ RSpec Agent  │  │ Docker Agent │           │ │   │  │
│  │  │  │  │ 1 CPU, 2GB   │  │ 2 CPU, 2GB   │           │ │   │  │
│  │  │  │  │ - Run tests  │  │ - Build img  │           │ │   │  │
│  │  │  │  │ - Lint code  │  │ - Push ECR   │           │ │   │  │
│  │  │  │  └──────────────┘  └──────────────┘           │ │   │  │
│  │  │  │  (Created per job, destroyed after)           │ │   │  │
│  │  │  └────────────────────────────────────────────────┘ │   │  │
│  │  └──────────────────────────────────────────────────────┘   │  │
│  └───────────────────────────┼──────────────────────────────────┘  │
│                              │                                     │
│  ┌───────────────────────────┼─────────────────────────────────┐  │
│  │        Data Layer         │                                 │  │
│  │                           │                                 │  │
│  │  ┌────────────────────────▼──────────────┐                 │  │
│  │  │  ElastiCache Redis (cache.t4g.micro)  │                 │  │
│  │  │  $11/month                            │                 │  │
│  │  │  ┌─────────────────────────────────┐  │                 │  │
│  │  │  │ - Session store                 │  │                 │  │
│  │  │  │ - Fragment cache (event cards)  │  │                 │  │
│  │  │  │ - E-score leaderboard (sorted)  │  │                 │  │
│  │  │  │ - Sidekiq job queue             │  │                 │  │
│  │  │  │ - Rate limiting counters        │  │                 │  │
│  │  │  └─────────────────────────────────┘  │                 │  │
│  │  └───────────────────────────────────────┘                 │  │
│  │                                                             │  │
│  │  ┌───────────────────────────────────────────────────────┐ │  │
│  │  │  RDS PostgreSQL (db.t3.micro)                         │ │  │
│  │  │  $17/month                                            │ │  │
│  │  │  ┌────────────────────────────────────────────────┐   │ │  │
│  │  │  │ Tables: users, event_posts,                    │   │ │  │
│  │  │  │         event_registrations,                   │   │ │  │
│  │  │  │         event_categories                       │   │ │  │
│  │  │  │                                                │   │ │  │
│  │  │  │ Search: PostgreSQL Full-Text Search            │   │ │  │
│  │  │  │         (pg_search gem)                        │   │ │  │
│  │  │  │         - Event name/description search        │   │ │  │
│  │  │  │         - Category filtering                   │   │ │  │
│  │  │  │         - Location-based queries               │   │ │  │
│  │  │  └────────────────────────────────────────────────┘   │ │  │
│  │  └───────────────────────────────────────────────────────┘ │  │
│  └─────────────────────────────────────────────────────────────┘  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                   External SaaS Services                          │
│                                                                   │
│  ┌─────────────────────┐  ┌──────────────────┐                  │
│  │   Datadog Pro       │  │   Sentry         │                  │
│  │   FREE (Student)    │  │   FREE (Student) │                  │
│  │   - APM traces      │  │   - Error track  │                  │
│  │   - Log aggregation │  │   - Performance  │                  │
│  │   - Infra metrics   │  │   - Releases     │                  │
│  │   - 10 servers      │  │                  │                  │
│  └─────────────────────┘  └──────────────────┘                  │
│                                                                   │
│  ┌─────────────────────┐  ┌──────────────────┐                  │
│  │   PagerDuty Free    │  │   Google Maps    │                  │
│  │   FREE (5 users)    │  │   FREE           │                  │
│  │   - On-call sched   │  │   < 10k req/mo   │                  │
│  │   - 100 SMS/month   │  │   - Geocoding    │                  │
│  └─────────────────────┘  └──────────────────┘                  │
└───────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────┐
│                      Request Flow Example                         │
│                                                                   │
│  User → CloudFront (static assets)                                │
│          ↓                                                        │
│  User → ALB (managed by Ingress) → Ingress routing               │
│          ↓                                                        │
│  Service (ClusterIP) → Rails Pod → PgBouncer → PostgreSQL        │
│                              │                                    │
│                              ├─→ Redis (check cache)              │
│                              │                                    │
│                              ├─→ PostgreSQL FTS (event search)    │
│                              │                                    │
│                              └─→ Sidekiq → Redis (enqueue job)    │
│                                                                   │
│  Every request sends trace → Datadog APM                          │
│  Every error sends event → Sentry                                 │
│  Critical alerts → PagerDuty → SMS/Email                          │
└───────────────────────────────────────────────────────────────────┘
```

## Cost Breakdown (per month)

### AWS Infrastructure
| Service | Instance Type | Monthly Cost |
|---------|--------------|--------------|
| EKS Control Plane | - | $72 |
| EC2 Nodes (Application) | 2x t3.medium | $60 |
| EC2 Nodes (Jenkins) | 1x t3.medium | $30 |
| Application Load Balancer | - | $16 |
| RDS PostgreSQL | db.t3.micro | $17 |
| ElastiCache Redis | cache.t4g.micro | $11 |
| Jenkins EBS Storage | 20GB gp3 | $2 |
| Data Transfer | ~5GB | $5 |
| **AWS Subtotal** | | **$213/month** |

### SaaS Services (FREE via GitHub Student Pack)
| Service | Normal Cost | Student Cost | Savings |
|---------|-------------|--------------|---------|
| Datadog Pro | $15/host × 2 = $30 | $0 | $30 |
| Sentry | $26 | $0 | $26 |
| PagerDuty | Free tier | $0 | $0 |
| Google Maps API | < 10k req/mo | $0 | $0 |
| **SaaS Subtotal** | | **$0/month** | **$56/month saved** |

### Total Monthly Cost: $213

**Budget: $600/month → Utilization: 35%**

## Technical Stack

### Application Layer
- **Framework**: Ruby on Rails 7.x
- **Web Server**: Puma (5 workers per pod)
- **Orchestration**: Kubernetes (EKS)
- **Ingress**: AWS Load Balancer Controller + Kubernetes Ingress
- **Deployment**: Argo Rollouts (progressive delivery)
- **Connection Pooling**: PgBouncer (sidecar pattern)

### CI/CD Layer
- **CI/CD Server**: Jenkins (self-hosted on EKS)
- **Controller**: 1x Jenkins controller (StatefulSet, 1 CPU, 2GB RAM)
- **Agents**: Dynamic Kubernetes pods (on-demand)
- **Build Triggers**: GitHub webhooks on PR/push
- **Artifact Storage**: Amazon ECR (Docker images)

### Data Layer
- **Primary Database**: PostgreSQL 16 (RDS)
- **Cache**: Redis 7.x (ElastiCache)
- **Search**: PostgreSQL Full-Text Search (pg_search gem)
- **Object Storage**: S3 (for user uploads, if needed)

### Async Processing
- **Job Queue**: Sidekiq + Redis
- **Use Cases**:
  - Email notifications (event reminders, registrations)
  - E-score calculations and leaderboard updates
  - Geocoding API calls (Google Maps)
  - Database cleanup tasks

### Observability
- **APM**: Datadog Agent (DaemonSet on each EKS node)
- **Error Tracking**: Sentry (sentry-rails gem in Rails app)
- **Logging**: Datadog Log Management
- **Metrics**: Datadog Infrastructure Monitoring
- **Alerting**: PagerDuty (on-call notifications)
- **Deployment**: Datadog Agent via Helm chart (DaemonSet pattern)

### CDN & Assets
- **CDN**: CloudFront
- **Static Assets**: Served via CloudFront (CSS, JS, images)
- **Cache TTL**: 1 hour for assets, 5 min for HTML

## Key Architecture Decisions

### 1. PostgreSQL FTS Instead of Elasticsearch
**Rationale**: At our scale (1000 students, ~5000 events), PostgreSQL full-text search provides:
- **Better performance**: 2-4ms vs 20ms (no network hop)
- **Lower complexity**: No additional service to manage
- **Lower cost**: $0 vs $10/month
- **Sufficient features**: Search, filtering, basic relevance ranking

**Crossover point**: Would consider Elasticsearch at 500k+ records or if advanced features needed (faceted search, autocomplete, fuzzy matching).

### 2. PgBouncer Sidecar Pattern
**Rationale**: Connection pooling prevents database connection exhaustion
- 3 pods × 5 Puma workers = 15 connections → pooled to 5-10 actual DB connections
- Allows db.t3.micro to handle more concurrent users
- Prevents need to scale up to db.t3.small ($34/month)

### 3. ElastiCache Redis (Managed) vs Self-Hosted
**Rationale**: Use managed Redis for production reliability
- Automatic failover and backups
- Multi-AZ replication
- Industry standard pattern
- $11/month is negligible compared to operational overhead

### 4. Sidekiq Instead of Kafka
**Rationale**: Sidekiq + Redis handles all async needs at scale
- **Cost**: $0 (uses existing Redis) vs $162/month for Kafka
- **Use cases**: Job queues, not event streaming
- **Complexity**: Much simpler than Kafka/MSK
- **Industry adoption**: Standard Rails pattern

**When Kafka makes sense**: Multi-consumer event streams, event sourcing, data pipelines to data warehouse

### 5. Jenkins on Dedicated Node
**Rationale**: Self-hosted Jenkins for CI/CD matches enterprise patterns
- **Cost**: $32/month (node + storage) vs GitHub Actions ($0 for 2000 min/month)
- **Isolation**: Dedicated node prevents builds from impacting Rails app performance
- **Flexibility**: Full control over plugins, build environment, integrations
- **Learning value**: Demonstrates K8s operations, StatefulSets, dynamic pod provisioning
- **Capacity**: Handles 4 developers × ~20 builds/day with ease

**Dynamic agent provisioning**: Jenkins controller spawns agent pods on-demand via Kubernetes plugin, scales to zero when idle.

### 6. Kubernetes Ingress + AWS Load Balancer Controller
**Rationale**: Cloud-native ingress management vs manual ALB configuration
- **GitOps-friendly**: Ingress resource versioned in Git with application code
- **Automatic management**: Controller creates/updates/deletes ALB based on Ingress changes
- **Industry standard**: Kubernetes Ingress API, portable pattern across cloud providers
- **Cost**: Same $16/month ALB cost, but managed declaratively

**Benefits**: SSL termination (ACM certificate), path-based routing, health checks, all defined in Kubernetes manifests.

### 7. GitHub Student Pack for Observability
**Rationale**: Free Datadog Pro + Sentry = $56/month savings
- **Datadog**: DaemonSet deployment (one agent per node), full APM, logs, and metrics (normally $30/month)
- **Sentry**: SDK-based instrumentation via sentry-rails gem (normally $26/month)
- 2-year benefit for Datadog Pro (10 hosts, unlimited containers)
- No separate agent containers needed - Datadog runs as DaemonSet, Sentry is a gem
- Production-grade tools, zero cost

**Deployment patterns:**
- Datadog: Helm chart creates DaemonSet (agent on each EKS node monitors all pods)
- Sentry: `gem 'sentry-rails'` + initializer configuration

## Scaling Considerations

### Current Capacity (1-Month Pilot)
- **Users**: 500-1000 students
- **Events**: ~5000 total events
- **Concurrent users**: ~100-200 peak
- **Requests/sec**: ~50 RPS peak

### Bottlenecks & Solutions
| Bottleneck | Current | Scale-Up Option | Cost Impact |
|------------|---------|-----------------|-------------|
| DB connections | db.t3.micro (30 conn) | PgBouncer pools to 5-10 | $0 |
| DB CPU/memory | db.t3.micro (1vCPU, 1GB) | db.t3.small (2vCPU, 2GB) | +$17/month |
| App servers | 3 pods, 5 workers each | Scale to 6 pods | +$30/month (1 more node) |
| Cache memory | 0.5GB Redis | cache.t4g.small (1.5GB) | +$20/month |
| Jenkins builds | 1 controller, 1-2 agents | Scale agent resources | $0 (same node) |

**Vertical scaling runway**: Current setup can handle 3-5x traffic before needing upgrades.

## Deployment Workflow

### CI/CD Pipeline (Jenkins)

**Pipeline stages (Jenkinsfile):**
```groovy
pipeline {
  agent none

  stages {
    stage('Test') {
      agent {
        kubernetes {
          label 'rspec-agent'
          yaml """
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: rails
                image: ruby:3.2
                command: ['cat']
                tty: true
                resources:
                  requests:
                    cpu: 1
                    memory: 2Gi
          """
        }
      }
      steps {
        sh 'bundle install'
        sh 'RAILS_ENV=test bundle exec rspec'
      }
    }

    stage('Build & Push') {
      agent {
        kubernetes {
          label 'docker-agent'
          yaml """
            apiVersion: v1
            kind: Pod
            spec:
              containers:
              - name: docker
                image: docker:latest
                command: ['cat']
                tty: true
                volumeMounts:
                - name: docker-sock
                  mountPath: /var/run/docker.sock
              volumes:
              - name: docker-sock
                hostPath:
                  path: /var/run/docker.sock
          """
        }
      }
      when { branch 'main' }
      steps {
        sh 'docker build -t e-ren:${GIT_COMMIT} .'
        sh 'docker tag e-ren:${GIT_COMMIT} ${ECR_REPO}:${GIT_COMMIT}'
        sh 'docker push ${ECR_REPO}:${GIT_COMMIT}'
      }
    }

    stage('Deploy') {
      when { branch 'main' }
      steps {
        sh 'kubectl argo rollouts set image e-ren-rollout e-ren=${ECR_REPO}:${GIT_COMMIT}'
        sh 'kubectl argo rollouts status e-ren-rollout'
      }
    }
  }

  post {
    failure {
      // Send to PagerDuty/Slack
      echo "Build failed - alerting on-call"
    }
    success {
      // Send Datadog deployment event
      sh 'curl -X POST "https://api.datadoghq.com/api/v1/events" ...'
    }
  }
}
```

**Build flow:**
1. **PR opened**: GitHub webhook → Jenkins → Spawn RSpec agent → Run tests → Report status
2. **Tests pass**: Jenkins comments on PR with test results
3. **Merge to main**: Trigger build pipeline
4. **Build stage**: Spawn Docker agent → Build image → Push to ECR
5. **Deploy stage**: Update Argo Rollouts with new image
6. **Progressive delivery**: Canary 20% → 50% → 100% (Argo Rollouts)
7. **Health checks**: Automatic rollback if Sentry error rate > 5%

**Jenkins plugins:**
- **Kubernetes Plugin**: Dynamic agent provisioning
- **GitHub Integration**: Webhooks, PR status updates
- **Pipeline**: Jenkinsfile support
- **Datadog Plugin**: Send build metrics and deployment events
- **Credentials**: AWS ECR, Kubernetes config

### Database Migrations
- **Development/Staging**: Automated in CI/CD
- **Production**: Manual review + backup before migration
  - Create RDS snapshot
  - Run migration during low-traffic window
  - Monitor with Datadog for slow queries

## Monitoring & Alerting

### Key Metrics (Datadog)
- **Application**: Request latency (p50, p95, p99), error rate, throughput
- **Database**: Connection count, query time, cache hit ratio
- **Infrastructure**: CPU/memory usage, pod restarts, node health
- **Business**: Event registrations/hour, active users, E-score updates
- **CI/CD**: Build duration, success rate, agent pod spawn time, deployment frequency

### Alert Thresholds (PagerDuty)
| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| Error rate | > 1% | > 5% | Check Sentry, rollback if needed |
| Response time | p95 > 500ms | p95 > 1s | Check slow queries in Datadog APM |
| DB connections | > 20 | > 25 | Investigate connection leaks |
| Pod restarts | > 3/hour | > 10/hour | Check logs, OOM issues |
| Jenkins build failure | > 3 consecutive | - | Check logs, notify team |

### On-Call Rotation
- **Primary**: Project lead (100 SMS/month via PagerDuty free tier)
- **Escalation**: Teammate after 15 min
- **Schedule**: 24/7 during 1-month pilot

## Security Considerations

### Network Security
- **VPC**: Private subnets for RDS, ElastiCache, EKS nodes
- **Security Groups**: Principle of least privilege
  - ALB: 80/443 from internet
  - EKS nodes: Only ALB + internal services
  - RDS: Only from EKS security group
  - ElastiCache: Only from EKS security group

### Application Security
- **Authentication**: Devise with school email verification
- **Rate Limiting**: Redis-based (rack-attack gem)
- **HTTPS**: Enforced via ALB + ACM certificate
- **Secrets**: AWS Secrets Manager (RDS passwords, API keys)
- **CORS**: Restrictive policy for API endpoints

### Data Security
- **Encryption at Rest**: RDS + EBS volumes
- **Encryption in Transit**: TLS 1.2+ everywhere
- **Backups**: RDS automated backups (7-day retention)
- **PII Handling**: Email addresses only, no SSN/payment data

## Cost Optimization Strategies

### Active Optimizations
1. **PgBouncer**: Prevents need for larger RDS instance ($17/month saved)
2. **Redis caching**: Reduces DB load, prevents scaling ($17/month saved)
3. **CloudFront**: Free tier covers all static assets ($10/month saved)
4. **Student Pack**: Free Datadog + Sentry ($56/month saved)
5. **PostgreSQL FTS**: Avoids Elasticsearch cost ($10/month saved)
6. **Dynamic Jenkins agents**: Ephemeral pods, only consume resources during builds ($0 idle cost)

**Total optimizations: ~$110/month saved**

### Future Optimizations (if needed)
- **Reserved Instances**: 30% savings on EC2 (only for long-term deployments)
- **Spot Instances**: For non-critical Sidekiq workers (50-70% savings)
- **S3 Lifecycle Policies**: Archive old event images to Glacier
- **RDS Storage Autoscaling**: Only pay for storage used

## Risk Mitigation

### Technical Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Database overload | Medium | High | PgBouncer + Redis caching + monitoring |
| Pod crashes (OOM) | Medium | Medium | Resource limits + autoscaling + alerts |
| Slow queries | Low | Medium | Datadog APM + query optimization |
| Cache miss storm | Low | High | Fragment caching + rate limiting |

### Operational Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Deployment failure | Low | High | Argo Rollouts canary + automatic rollback |
| Data loss | Very Low | Critical | RDS automated backups + snapshots |
| Security breach | Low | Critical | Security groups + secrets management + HTTPS |
| Cost overrun | Low | Medium | CloudWatch billing alerts at $200, $400, $550 |
| Jenkins controller crash | Low | Medium | StatefulSet auto-restart + PersistentVolume preserves data |

## Next Steps

### Pre-Deployment Checklist
- [ ] Apply for GitHub Student Developer Pack (get Datadog Pro + Sentry)
- [ ] Apply for AWS Educate ($100-200 credits)
- [ ] Set up AWS account with MFA and billing alerts
- [ ] Create EKS cluster with Terraform/eksctl (3 node groups: app, jenkins, system)
- [ ] Install AWS Load Balancer Controller (Helm chart)
- [ ] Request ACM certificate for eren.washu.edu
- [ ] Configure RDS PostgreSQL with automated backups
- [ ] Set up ElastiCache Redis cluster
- [ ] Deploy Jenkins controller (StatefulSet + PersistentVolume)
- [ ] Configure Jenkins plugins (Kubernetes, GitHub, Datadog)
- [ ] Set up Jenkins GitHub webhooks for PR builds
- [ ] Create ECR repository for Docker images
- [ ] Install Datadog Agent via Helm (creates DaemonSet on all nodes)
- [ ] Add sentry-rails gem and configure DSN
- [ ] Configure PagerDuty alerts
- [ ] Create CloudFront distribution
- [ ] Create Ingress resource (auto-creates ALB)
- [ ] Set up Argo Rollouts for progressive delivery
- [ ] Test Jenkins pipeline with sample PR
- [ ] Run load tests (simulate 200 concurrent users)
- [ ] Document runbook for common incidents

### Learning Objectives
As preparation for full-time role, focus on:
1. **Kubernetes**: Pod management, deployments, StatefulSets, PersistentVolumes, node affinity
2. **CI/CD**: Jenkins administration, pipeline-as-code, dynamic agent provisioning
3. **Observability**: Reading APM traces, setting up alerts, debugging with logs
4. **Database Operations**: Query optimization, connection pooling, backup/restore
5. **Progressive Deployment**: Canary releases, rollback strategies, Argo Rollouts
6. **Incident Response**: Using runbooks, reading metrics, root cause analysis

### Jenkins-Specific Learning
- **StatefulSets**: Persistent workloads in Kubernetes (Jenkins controller with PVC)
- **Dynamic Provisioning**: Kubernetes plugin spawning agent pods on-demand
- **Pipeline DSL**: Declarative and scripted Jenkinsfiles
- **Credentials Management**: AWS credentials, kubeconfig, GitHub tokens
- **Plugin Ecosystem**: Kubernetes, GitHub, Datadog, Pipeline plugins
- **Resource Management**: CPU/memory limits for ephemeral agent pods

---

**Document Version**: 1.1
**Last Updated**: 2025-11-03
**Author**: Dean (with Claude Code assistance)
**Status**: Architecture approved with Jenkins CI/CD, ready for implementation

## Appendix: Kubernetes Configuration Examples

### Datadog Agent DaemonSet Installation
```bash
# Install Datadog via Helm (creates DaemonSet)
helm repo add datadog https://helm.datadoghq.com
helm repo update

helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=$DD_API_KEY \
  --set datadog.site=datadoghq.com \
  --set datadog.apm.enabled=true \
  --set datadog.logs.enabled=true \
  --set datadog.logs.containerCollectAll=true \
  --set datadog.processAgent.enabled=true
```

This creates a DaemonSet that runs one Datadog Agent pod per node.

### Sentry Configuration (Rails Gem)
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set traces_sample_rate to 1.0 to capture 100% of transactions for performance monitoring
  config.traces_sample_rate = 1.0

  # Set profiles_sample_rate to profile 100% of sampled transactions
  config.profiles_sample_rate = 1.0

  config.environment = Rails.env
  config.enabled_environments = %w[production staging]
end
```

No sidecar container needed - Sentry SDK sends data directly from Rails app.

### AWS Load Balancer Controller Installation
```bash
# Create IAM policy for Load Balancer Controller
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# Create IAM service account
eksctl create iamserviceaccount \
  --cluster=eren-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve

# Install via Helm
helm repo add eks https://aws.github.io/eks-charts
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=eren-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

### Ingress Resource (Creates ALB Automatically)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eren-ingress
  namespace: production
  annotations:
    # ALB configuration
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '30'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'

    # SSL/TLS
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:ACCOUNT_ID:certificate/CERT_ID

    # Performance
    alb.ingress.kubernetes.io/load-balancer-attributes: idle_timeout.timeout_seconds=60

spec:
  rules:
  - host: eren.washu.edu
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: eren-service
            port:
              number: 3000
```

### Rails Application Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: eren-service
  namespace: production
spec:
  type: ClusterIP  # Internal only, ALB routes to this
  selector:
    app: eren
  ports:
  - protocol: TCP
    port: 3000
    targetPort: 3000
```

### Jenkins Controller StatefulSet
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jenkins
  namespace: ci-cd
spec:
  serviceName: jenkins
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      nodeSelector:
        workload: jenkins  # Ensures controller runs on dedicated Jenkins node
      containers:
      - name: jenkins
        image: jenkins/jenkins:lts
        ports:
        - containerPort: 8080
          name: http
        - containerPort: 50000
          name: agent
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "1"
            memory: "2Gi"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        env:
        - name: JAVA_OPTS
          value: "-Xmx1800m -Dhudson.slaves.NodeProvisioner.initialDelay=0"
  volumeClaimTemplates:
  - metadata:
      name: jenkins-home
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: gp3
      resources:
        requests:
          storage: 20Gi
```

### Required Jenkins Plugins
```
kubernetes:latest
workflow-aggregator:latest
git:latest
github:latest
datadog:latest
credentials-binding:latest
docker-workflow:latest
```

### Kubernetes Cloud Configuration (Jenkins)
```
Name: kubernetes
Kubernetes URL: https://kubernetes.default.svc.cluster.local
Kubernetes Namespace: ci-cd
Jenkins URL: http://jenkins.ci-cd.svc.cluster.local:8080
Jenkins Tunnel: jenkins.ci-cd.svc.cluster.local:50000
```

### Sample Agent Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
    resources:
      requests:
        cpu: "500m"
        memory: "512Mi"
  - name: rails
    image: ruby:3.2
    command: ["cat"]
    tty: true
    resources:
      requests:
        cpu: "1"
        memory: "2Gi"
      limits:
        cpu: "2"
        memory: "2Gi"
```
