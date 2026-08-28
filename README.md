# DevOps Practical Assessment

This repository contains the six requested practical tasks: Kubernetes, Nginx, Docker, MySQL backup automation, GitHub Actions CI/CD, and troubleshooting. It also records local validation, external-service limitations, implementation decisions, and AI assistance.

## Repository structure

```text
devops-practical/
├── .github/workflows/ci-cd.yml
├── README.md
├── task-1-kubernetes/
│   ├── deployment.yaml
│   └── service.yaml
├── task-2-nginx/
│   └── nginx.conf
├── task-3-docker/
│   ├── .dockerignore
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   ├── server.js
│   ├── sonar-project.properties
│   └── test/server.test.js
├── task-4-backup/
│   ├── backup.sh
│   ├── retention-approach.md
│   └── s3-lifecycle.json
├── task-5-cicd/
│   ├── github-actions.yml
│   └── README.md
└── evidence/
    ├── implementation-log.md
    ├── troubleshooting-approach.md
    └── test-evidence/local-validation.md
```

## Prerequisites

- Git.
- Docker Engine or Docker Desktop.
- Node.js 24 or newer and npm for host tests.
- `kubectl` plus access to a test Kubernetes cluster for runtime deployment.
- Bash, MySQL 8 client tools, gzip, coreutils, and AWS CLI v2 for the backup script.
- An AWS account only for the cloud portions: an S3 bucket, ECR repository, Systems Manager-managed Ubuntu EC2 instance, and least-privilege IAM roles.
- A SonarQube project/server and project-scoped analysis token for the quality stage.

Do not place credentials in this repository. Use a protected MySQL option file, EC2 instance roles, GitHub OIDC, GitHub Actions secrets, and variables as described below.

## Task 1 - Kubernetes

The Deployment runs two `nginx:latest` replicas with requests/limits, readiness/liveness probes, explicit RollingUpdate settings, stable labels, and a restricted container security context. The `ClusterIP` Service exposes port 80 only inside the cluster.

```bash
kubectl apply -f task-1-kubernetes/deployment.yaml \
  -f task-1-kubernetes/service.yaml
kubectl rollout status deployment/nginx
kubectl get deployment,pods,service,endpointslices -l app.kubernetes.io/name=nginx
kubectl port-forward service/nginx 8080:80
curl --fail http://127.0.0.1:8080/
```

Local schema validation passed with Kubeconform against Kubernetes 1.34. A live-cluster runtime test was not claimed because no safe cluster context was available.

## Task 2 - Nginx

The configuration permanently redirects `abc.com` to `www.abc.com` while preserving the URI, then proxies `www.abc.com` to `127.0.0.1:3000` with forwarding headers.

```bash
docker run --rm \
  --mount type=bind,source="$PWD/task-2-nginx/nginx.conf",target=/etc/nginx/nginx.conf,readonly \
  nginx:latest nginx -t
```

Syntax testing and an end-to-end redirect/proxy test against the included Node.js application both passed. The localhost upstream requires Nginx and the backend to share a host or network namespace.

## Task 3 - Docker

The small Node.js application exposes `/` and `/health` on port 3000. It has no external packages or compilation step.

```bash
cd task-3-docker
npm ci
npm test
docker build --pull -t devops-practical-app:local .
docker run --rm -p 3000:3000 devops-practical-app:local
```

In another terminal:

```bash
curl --fail http://127.0.0.1:3000/
curl --fail http://127.0.0.1:3000/health
```

The first implementation deliberately kept the candidate's live-interview `FROM node:latest` choice, but the real GitHub Trivy gate found 417 HIGH/CRITICAL OS findings and 4 HIGH Node-package findings. The corrected Dockerfile keeps the recognizable `/app`, dependency-copy, source-copy, and `ENTRYPOINT ["node", "server.js"]` structure while using an official multi-stage pattern: npm runs only in a digest-pinned Node 24 LTS builder, and the final digest-pinned Alpine runtime contains Node and the app without npm/Yarn. The exact OpenSSL fixed version reported by Trivy is installed. No finding was suppressed.

## Task 4 - MySQL backup to S3

Required configuration:

```bash
export MYSQL_HOST='<mysql-host>'
export MYSQL_DATABASE='<database_name>'
export MYSQL_USER='<backup-user>'
export MYSQL_PORT='3306'                     # optional
export MYSQL_DEFAULTS_FILE="$HOME/.my.cnf"  # optional protected password file
export S3_BUCKET='<bucket-name>'
export S3_PREFIX='mysql-backups'             # optional
export AWS_REGION='<aws-region>'
```

Example protected MySQL option file; create it outside the repository and set mode `600`:

```ini
[client]
password=replace-with-the-real-secret
```

Run the backup:

```bash
chmod 700 task-4-backup/backup.sh
./task-4-backup/backup.sh
```

The script creates a restricted temporary `<database>_<UTC timestamp>.sql.gz`, runs `gzip -t`, uploads with SSE-S3, verifies the remote object size with `head-object`, and removes the local temporary directory on every exit. Any critical failure returns non-zero.

The runtime AWS identity needs `s3:PutObject` and `s3:GetObject` on the configured prefix. To inspect objects manually, an operator with `s3:ListBucket` can run:

```bash
aws s3 ls "s3://$S3_BUCKET/${S3_PREFIX:-mysql-backups}/" --region "$AWS_REGION"
```

Apply and verify seven-day S3 retention using the commands in `task-4-backup/retention-approach.md`. The lifecycle administrator separately needs `s3:PutLifecycleConfiguration` and `s3:GetLifecycleConfiguration`.

## Task 5 - GitHub Actions CI/CD

The executable workflow is `.github/workflows/ci-cd.yml`; `task-5-cicd/github-actions.yml` is an identical assessment copy. A push to `main` runs tests, configured SonarQube analysis, Docker build, and the fail-closed Trivy HIGH/CRITICAL gate. A deliberate manual run with `deploy=true` additionally performs the OIDC-authenticated ECR push, Systems Manager deployment to one Ubuntu EC2 instance, and remote health check after validating all required external settings.

Required GitHub variables, the `SONAR_TOKEN` secret, AWS permissions, EC2 prerequisites, failure behavior, and vulnerability assumptions are documented in `task-5-cicd/README.md`.

Cloud stages were not run because no approved SonarQube/AWS assessment infrastructure was supplied. Their configuration was linted and the generated Systems Manager request/remote shell commands were tested offline.

## Task 6 - Troubleshooting

`evidence/troubleshooting-approach.md` covers:

- Pod `Running` but `READY 0/1`.
- Healthy Pods inaccessible through a Service.
- Nginx returning 502 for a port-3000 upstream.
- A slow Ubuntu production server with an unavailable application.

Each scenario starts with evidence collection, explains why each check matters, and branches based on results.

## Validation summary

| Area | Result | Limitation |
|---|---|---|
| Kubernetes | 2/2 manifests passed strict schema validation | No live cluster/admission test |
| Nginx | `nginx -t`, HTTP 301, and reverse proxy passed | Local Docker namespace test |
| Node.js | 5/5 tests passed | Minimal sample application |
| Docker | Hardened multi-stage build, endpoints, UID 1000, and absence of npm/Yarn in the final image passed | Digest/package pins require routine security updates |
| Backup | Bash, ShellCheck, failure path, real local MySQL dump/gzip, and lifecycle input passed | S3 boundary mocked; no real IAM/S3 run |
| CI/CD | Copies identical, Actionlint passed, SSM JSON/AWS input parse and six shell syntax checks passed | No SonarQube/ECR/EC2 execution |
| Trivy | Initial image failed closed; hardened `main` retest passed with 0 Alpine and 0 Node-package findings at HIGH/CRITICAL | Re-scan every rebuilt/updated image |

See `evidence/implementation-log.md` for the chronological commands, real errors, corrections, outputs, decisions, and remaining external checks.

## Assumptions and implementation decisions

- The assessment supplied no Node.js source, so a dependency-free sample service and tests are included.
- The required Kubernetes Service is internal `ClusterIP`.
- `nginx:latest` is retained where explicitly requested. The Docker task began with the candidate's `node:latest` interview draft, but the real fail-closed scan required a digest-pinned Node 24 LTS builder and minimal Alpine runtime.
- AWS resources, identifiers, credentials, SonarQube, and a Kubernetes cluster are not assumed.
- GitHub OIDC and EC2 instance roles are used instead of long-lived AWS keys.
- Systems Manager is used instead of SSH. The required single-instance replacement may have brief downtime; high availability would require multiple targets and rolling or blue/green deployment.
- Repository evidence contains no real secrets, tokens, production IP addresses, or customer data.

## AI usage and engineering review

### Tool

An OpenAI AI coding assistant was used. Official vendor documentation and local validation tools were also consulted.

### Purpose

AI assistance was used to extract and organize the assessment requirements, research official documentation, draft infrastructure/configuration files, create the minimal Node.js test application, reason through errors, orchestrate local validation, and maintain the implementation log.

### Manual review and modifications

The candidate supplied the simple Dockerfile structure used during the live interview and asked that it remain recognizable. The first working version preserved it closely. After the mandatory online scan found real HIGH/CRITICAL issues in `node:latest`, the final version retained the `/app`, copy, port, non-root, and direct Node entrypoint choices but adopted the official multi-stage runtime-hardening pattern. AI-produced work was compared with the source requirements and revised after actual lint, build, runtime, integration, and security-gate failures.

Candidate review is still required before submission. The candidate should read every file, replace no placeholders with secrets, and be able to explain the Kubernetes selectors/probes, Nginx namespace assumption, Dockerfile trade-offs, backup credential/retention model, Trivy gate, OIDC trust, IAM permissions, SSM deployment, and every unexecuted external validation. This README must not be changed to claim a candidate review or cloud test until that review/test actually occurs.

### Validation

AI-assisted artifacts were checked using Node's test runner, Docker build/run/inspect, Nginx syntax and HTTP integration tests, Kubeconform, ShellCheck, Bash parsing, AWS CLI offline input parsing, Actionlint, generated-command parsing, and official documentation. Only completed checks are reported as passed; external-service limitations remain explicit.

## Before submission

- Complete the candidate review described above.
- Re-run the commands in `evidence/test-evidence/local-validation.md`.
- Keep the Node/Alpine digests and fixed Alpine package versions current through reviewed updates, and require the unchanged Trivy gate to pass after every update.
- If assessment infrastructure is provided, run the Kubernetes, SonarQube, S3/IAM, ECR, SSM, EC2, and health checks and add sanitized evidence.
- Confirm the intended Git name/email and GitHub account before committing.
- Confirm repository visibility and reviewer access before sharing the link.
- Do not commit `.env` files, option files, credentials, tokens, keys, or raw cloud output containing sensitive infrastructure details.
