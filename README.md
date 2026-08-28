# DevOps Practical Assessment

This repository is my submission for the DevOps practical assessment. I implemented all six tasks, tested each component as far as the available local environment allowed, and documented the results and limitations without claiming unavailable cloud execution.

## Solution overview

| Task | What I implemented | Main evidence |
|---|---|---|
| Kubernetes | Two-replica NGINX Deployment and internal `ClusterIP` Service with probes, resources, labels, and rolling updates | Strict schema validation passed for both manifests |
| Nginx | HTTP 301 redirect from `abc.com` to `www.abc.com` and reverse proxy to `127.0.0.1:3000` | Syntax, redirect, and proxy integration tests passed |
| Docker | Minimal Node.js service, tests, and a non-root multi-stage image | Build, tests, endpoints, UID, and Trivy gate passed |
| Backup | MySQL dump, gzip compression, S3 upload verification, error handling, and seven-day retention | ShellCheck, failure-path, and isolated MySQL integration tests passed |
| CI/CD | GitHub Actions pipeline for test, SonarQube, image build, Trivy, ECR, SSM deployment, and health checking | Actionlint and offline command validation passed; GitHub build/Trivy run passed |
| Troubleshooting | Evidence-driven investigation plans for Kubernetes, Nginx, and Ubuntu incidents | All four requested scenarios are documented |

## Repository layout

```text
devops-practical/
├── .github/workflows/ci-cd.yml
├── README.md
├── task-1-kubernetes/
├── task-2-nginx/
├── task-3-docker/
├── task-4-backup/
├── task-5-cicd/
└── evidence/
```

I kept the root README focused on my solution and reproducibility. Detailed command history, errors, fixes, and outputs are recorded in [the implementation log](evidence/implementation-log.md), and the concise executed results are in [local validation evidence](evidence/test-evidence/local-validation.md).

## Environment and prerequisites

I used the following tools while implementing and validating the assessment. Equivalent versions can be used to reproduce the checks.

- Git.
- Docker Engine or Docker Desktop.
- Node.js 24 or newer and npm.
- `curl` for HTTP endpoint and redirect checks.
- `kubectl` and a test cluster for live Kubernetes execution.
- Nginx, or the `nginx:latest` container image, for configuration testing.
- Bash, MySQL 8 client tools, gzip, coreutils, and AWS CLI v2 for the backup task.
- SonarQube and an AWS environment only for the external CI/CD stages.

No credential is stored in this repository. The AWS design uses GitHub OIDC and EC2 instance roles, while the backup supports a protected MySQL option file.

GitHub authentication is not required to clone this public repository, run the local checks, or view the existing workflow results. Running a new workflow in the original repository is limited to accounts with write access. An independent copy can be tested by forking the repository and running the same workflow in the fork.

## Task 1 - Kubernetes

I created a two-replica NGINX Deployment with resource requests and limits, readiness and liveness probes, explicit `RollingUpdate` settings, stable labels, and a restricted container security context. The Service is internal because the assessment requires internal exposure.

Files:

- [deployment.yaml](task-1-kubernetes/deployment.yaml)
- [service.yaml](task-1-kubernetes/service.yaml)

Commands I would use for the required live-cluster validation:

```bash
kubectl apply -f task-1-kubernetes/deployment.yaml \
  -f task-1-kubernetes/service.yaml
kubectl rollout status deployment/nginx
kubectl get deployment nginx
kubectl get pods -l app.kubernetes.io/name=nginx
kubectl get service nginx
kubectl get endpointslices -l kubernetes.io/service-name=nginx
kubectl port-forward service/nginx 8080:80
curl --fail http://127.0.0.1:8080/
```

Both manifests passed strict Kubeconform validation against Kubernetes 1.34. I did not claim a live-cluster deployment because no safe test cluster was available.

## Task 2 - Nginx reverse proxy

I configured `abc.com` to return HTTP 301 to the same URI on `www.abc.com`. Requests for `www.abc.com` are proxied to the application on `127.0.0.1:3000` with the standard forwarding headers.

File: [nginx.conf](task-2-nginx/nginx.conf)

The syntax check I used was:

```bash
docker run --rm \
  --mount type=bind,source="$PWD/task-2-nginx/nginx.conf",target=/etc/nginx/nginx.conf,readonly \
  nginx:latest nginx -t
```

Expected behavior:

- `http://abc.com/example?source=test` returns HTTP 301 with `Location: http://www.abc.com/example?source=test`.
- `http://www.abc.com/` returns the response from the application on port 3000.

I also ran the following end-to-end local test after building the Task 3 image. Because the required upstream is `127.0.0.1:3000`, I placed Nginx in the application container's network namespace. I published Nginx only on the host loopback interface for this test.

```bash
docker run --detach --name rlogical-practical-app \
  --publish 127.0.0.1:8080:80 \
  rlogical-practical-app:local

docker run --detach --name rlogical-nginx-test \
  --network container:rlogical-practical-app \
  --mount type=bind,source="$PWD/task-2-nginx/nginx.conf",target=/etc/nginx/nginx.conf,readonly \
  nginx:latest

curl --silent --show-error --retry 10 --retry-connrefused --retry-delay 1 \
  --dump-header - --output /dev/null --noproxy "*" \
  --resolve abc.com:8080:127.0.0.1 \
  "http://abc.com:8080/example?source=test"

curl --fail --silent --show-error --noproxy "*" \
  --resolve www.abc.com:8080:127.0.0.1 \
  http://www.abc.com:8080/

docker rm --force rlogical-nginx-test rlogical-practical-app
```

The test returned the expected HTTP 301 `Location` header and the proxied application response.

## Task 3 - Dockerized Node.js application

The assessment did not provide application source, so I added a dependency-free Node.js service with `/` and `/health` endpoints plus five tests. I began with the simple Dockerfile structure I wrote during the live interview, then corrected its install, startup, caching, and security issues.

Files:

- [Dockerfile](task-3-docker/Dockerfile)
- [.dockerignore](task-3-docker/.dockerignore)
- [server.js](task-3-docker/server.js)
- [server.test.js](task-3-docker/test/server.test.js)

Complete workflow I used:

```bash
cd task-3-docker
npm ci
npm test

docker build --pull -t rlogical-practical-app:local .
APP_HOST_PORT=3000
# I use APP_HOST_PORT=33000 when host port 3000 is already occupied.
docker run -d --name rlogical-practical-app \
  --publish "127.0.0.1:${APP_HOST_PORT}:3000" \
  rlogical-practical-app:local

docker ps --filter name=rlogical-practical-app
docker logs rlogical-practical-app
curl --fail --retry 10 --retry-connrefused --retry-delay 1 \
  "http://127.0.0.1:${APP_HOST_PORT}/health"
curl --fail "http://127.0.0.1:${APP_HOST_PORT}/"
docker exec rlogical-practical-app node --version

docker stop rlogical-practical-app
docker rm rlogical-practical-app
docker rmi rlogical-practical-app:local
```

The first `node:latest` image failed the real GitHub Trivy gate with 417 HIGH/CRITICAL OS findings and 4 HIGH Node-package findings. I kept the recognizable `/app` and direct Node entrypoint structure, but changed the implementation to a digest-pinned Node 24 builder and a minimal digest-pinned Alpine runtime without npm or Yarn. After installing the fixed OpenSSL packages reported by Trivy, the unchanged gate passed with zero HIGH/CRITICAL findings.

## Task 4 - MySQL backup to S3

I wrote [backup.sh](task-4-backup/backup.sh) to create a compressed MySQL dump, validate the gzip archive, upload it with SSE-S3, verify the uploaded object size, and remove temporary local data on every exit. A critical failure returns a non-zero exit code.

Configuration used by the script:

```bash
export MYSQL_HOST='<mysql-host>'
export MYSQL_DATABASE='<database-name>'
export MYSQL_USER='<backup-user>'
export MYSQL_PORT='3306'
export MYSQL_DEFAULTS_FILE="$HOME/.my.cnf"
export S3_BUCKET='<bucket-name>'
export S3_PREFIX='mysql-backups'
export AWS_REGION='<aws-region>'
```

Example protected MySQL option file stored outside the repository:

```ini
[client]
password=<mysql-password>
```

Execution and verification commands:

```bash
chmod 700 task-4-backup/backup.sh
./task-4-backup/backup.sh

aws s3 ls "s3://$S3_BUCKET/${S3_PREFIX:-mysql-backups}/" \
  --region "$AWS_REGION"
```

The runtime identity needs `s3:PutObject` and `s3:GetObject` on the configured prefix. An identity used for manual listing also needs `s3:ListBucket`.

I chose an S3 Lifecycle rule for seven-day retention because AWS can enforce retention independently of whether the backup server is running. The reproducible configuration is in [s3-lifecycle.json](task-4-backup/s3-lifecycle.json) and the decision is explained in [retention-approach.md](task-4-backup/retention-approach.md).

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$S3_BUCKET" \
  --lifecycle-configuration file://task-4-backup/s3-lifecycle.json

aws s3api get-bucket-lifecycle-configuration \
  --bucket "$S3_BUCKET"
```

The lifecycle administrator additionally needs `s3:PutLifecycleConfiguration` and `s3:GetLifecycleConfiguration`. I validated a real dump and gzip archive against an isolated MySQL 8 container. I mocked only the AWS command boundary because no assessment bucket or IAM role was supplied.

## Task 5 - GitHub Actions CI/CD

The executable workflow is [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml). The requested assessment copy is [task-5-cicd/github-actions.yml](task-5-cicd/github-actions.yml), and both files are identical.

My pipeline performs:

1. Checkout, Node.js 24 setup, dependency installation, and tests.
2. SonarQube analysis when its URL and token are configured.
3. Docker image build tagged with the immutable Git commit SHA.
4. Fail-closed Trivy scanning for HIGH and CRITICAL OS/application findings.
5. Short-lived GitHub OIDC authentication and ECR push.
6. Deployment to one Systems Manager-managed Ubuntu EC2 instance.
7. EC2-local application health checking.

GitHub configuration required for the external stages:

- Variables: `SONAR_HOST_URL`, `AWS_ROLE_TO_ASSUME`, `AWS_REGION`, `ECR_REPOSITORY`, and `EC2_INSTANCE_ID`.
- Secret: `SONAR_TOKEN` with project-analysis scope.
- A protected `production` environment for deployment approval.

A push to `main` runs tests, optional configured SonarQube analysis, image build, and the mandatory Trivy gate. I made deployment an explicit manual action using `workflow_dispatch` with `deploy=true`, so a normal source push cannot accidentally publish or replace a server.

For a manual validation-only run as the repository owner, I open **Actions → DevOps Practical CI/CD → Run workflow** and leave `deploy` set to `false`. The same workflow can be run independently from the Actions page of a fork.

I use `deploy=true` only after the documented SonarQube and AWS settings are available.

The integrated `main` workflow passed application tests, image build, and Trivy with zero HIGH/CRITICAL findings. Its [successful GitHub Actions run](https://github.com/anshum940/rlogical-practical-assessment/actions/runs/33204905174) is publicly viewable.

I did not claim SonarQube, ECR, SSM, or EC2 execution because the required external infrastructure and settings were not supplied. I validated the workflow syntax, AWS request shapes, and all generated remote shell commands offline. IAM expectations and deployment behavior are documented in [the CI/CD notes](task-5-cicd/README.md).

## Task 6 - Troubleshooting approach

My [troubleshooting document](evidence/troubleshooting-approach.md) covers all four requested scenarios:

- Pod `Running` but `READY 0/1`.
- Healthy Pods inaccessible through a Service.
- Nginx returning 502 for the port-3000 upstream.
- Slow Ubuntu production server with an unavailable application.

For each scenario, I start by scoping impact and collecting evidence, explain why each check matters, and choose the next step based on the result instead of jumping directly to a restart or configuration change.

## Validation summary

| Area | Result | Limitation |
|---|---|---|
| Kubernetes | 2/2 manifests passed strict schema validation | No live cluster/admission test |
| Nginx | Syntax, HTTP 301, and reverse proxy passed | Local namespace integration test |
| Node.js | 5/5 tests passed | Minimal assessment application |
| Docker | Build, endpoints, UID 1000, and minimal runtime checks passed | Image pins require routine security updates |
| Backup | ShellCheck, Bash parsing, failure path, real local dump/gzip, and lifecycle input passed | AWS boundary mocked; no real S3/IAM run |
| CI/CD | Workflow copies, Actionlint, AWS input parsing, and remote shell parsing passed | No SonarQube/ECR/EC2 execution |
| Trivy | Initial image failed closed; hardened `main` image passed with zero HIGH/CRITICAL findings | Re-scan every rebuilt image |

## Assumptions and decisions

- I added a minimal Node.js application because source code was not supplied.
- I used an internal `ClusterIP` Service as requested.
- I retained `nginx:latest` because the task explicitly requires it.
- I changed my original `node:latest` Docker approach only after the required security gate proved it unsuitable.
- I used GitHub OIDC and EC2 instance roles instead of long-lived AWS keys.
- I used Systems Manager instead of SSH. A single-instance replacement may cause brief downtime; a production highly available service would use multiple targets with rolling or blue/green deployment.
- I treated missing cloud infrastructure as a documented limitation rather than inventing successful results.

## Issues encountered and fixes

1. **My interview Dockerfile used `npm -I`, expected a build step that did not exist, and used shell-form `entrypoint`.** I changed the install to deterministic `npm ci`, removed the unnecessary build assumption, improved layer ordering, and used exec-form `ENTRYPOINT`.
2. **Local Trivy database downloads did not complete.** I kept the gate fail-closed and used the GitHub-hosted run for the definitive result.
3. **The first online image scan failed with hundreds of HIGH/CRITICAL findings.** I moved npm to a builder stage and removed npm/Yarn from the runtime image.
4. **The first hardened image still had two HIGH OpenSSL findings.** I installed the fixed versions reported by Trivy and reran the same unchanged gate successfully.
5. **No SonarQube or AWS deployment infrastructure was available.** I kept those stages fully configured, made deployment explicit, validated what could be checked offline, and documented the exact remaining configuration.

The full chronological error and correction record is available in [evidence/implementation-log.md](evidence/implementation-log.md).

## AI usage and engineering review

### Tool

I used an OpenAI coding assistant together with official vendor documentation and local validation tools.

### Purpose

I used AI assistance to organize the requirements, research unfamiliar details, draft initial configuration and documentation, investigate errors, and structure repeatable validation.

### Manual review and modifications

I supplied the simple Dockerfile structure from my live interview and made the main implementation decisions, including keeping Trivy and SonarQube in the pipeline and retaining a fail-closed security policy. The initial drafts were modified after actual syntax, build, runtime, integration, and security failures. Before submission, I will complete a final file-by-file review and make sure I can explain every configuration and limitation.

### Validation

I validated the work with Node's test runner, Docker build/run/inspect, Nginx syntax and HTTP integration tests, Kubeconform, ShellCheck, Bash parsing, AWS CLI offline input parsing, Actionlint, generated-command parsing, GitHub Actions, Trivy, and official documentation. I report only checks that actually completed and keep all external-service limitations explicit.

## Evidence

- [Implementation log](evidence/implementation-log.md): chronological commands, decisions, errors, fixes, and results.
- [Local validation evidence](evidence/test-evidence/local-validation.md): concise executed outputs.
- [Troubleshooting approach](evidence/troubleshooting-approach.md): investigation methodology for the four scenarios.
