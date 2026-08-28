# Implementation Log

I use this file as the chronological source of truth for my assessment. It records my decisions, commands, actual results, errors, fixes, limitations, and remaining work. I intentionally omit wall-clock timestamps; the order of entries preserves the work sequence.

## Objective

My objective was to produce a small, reproducible DevOps assessment repository containing:

- Kubernetes manifests for NGINX.
- An Nginx redirect and reverse-proxy configuration.
- A runnable Node.js sample and production-oriented Dockerfile.
- A MySQL-to-S3 backup script with seven-day retention configuration.
- A GitHub Actions pipeline covering test, SonarQube, image build, Trivy, ECR, EC2 deployment, and health checking.
- Troubleshooting methodology, validation evidence, assumptions, and an accurate AI-assistance disclosure.

## Working principles

- Follow the assessment's explicit requirements even when a production recommendation differs; document the trade-off.
- Use least privilege, short-lived credentials, deterministic configuration, fail-fast behavior, and clear rollback paths.
- Never commit credentials or sensitive infrastructure information.
- Record only tests that were actually run. Do not fabricate outputs or failures.
- Keep generated evidence free of wall-clock timestamps where the command supports stable output; never alter a timestamp to misrepresent when a test occurred.
- I must complete a final manual review before submission so I can explain every decision.

## Phase 1 - Source review and environment audit

### Discussion and decisions

- The supplied assessment permits official documentation, search, AI tools, and local development tools, but requires the submitted work to be understood and validated.
- The assessment's final repository tree is treated as authoritative because it contains additional required files omitted from the earlier example.
- The repository is located in the `devops-practical/` subdirectory so unrelated local review files are not included in Git.
- Cloud resources and credentials were not provided. AWS-dependent stages will be implemented completely but not claimed as executed.
- A minimal Node.js application will be included under `task-3-docker/` because the brief provides only an assumed layout. This makes the Docker and CI/CD tasks independently reproducible.
- The runnable GitHub workflow must exist under `.github/workflows/`. A synchronized assessment copy will also be kept at the explicitly requested `task-5-cicd/github-actions.yml` path.

### Commands executed

```text
rg --files -g '!review_artifacts/**'
Get-Command git,docker,kubectl,kind,minikube,helm,nginx,wsl,bash,shellcheck,aws,mysqldump,mysql,node,npm,trivy,actionlint,yamllint,yq,python,python3
git --version
git config --show-origin --get user.name
git config --show-origin --get user.email
git status --short --branch
docker version
docker image ls
wsl --list --verbose
```

### Relevant outputs

```text
Git: 2.55.0.windows.2
Docker client/server: 29.5.3
Docker Desktop: 4.77.0
kubectl: available
AWS CLI: available
Node.js/npm: available
WSL command: available, but no Linux distribution is installed
Git repository: not initialized
Git user.name: not configured
Git user.email: not configured
```

Cached container images relevant to validation include `nginx:latest`, `nginx:alpine`, `mysql:8`, `amazon/aws-cli:latest`, and `koalaman/shellcheck:stable`.

### Errors, root causes, and resolutions

1. **Initial Docker inspection failed with access denied to the Docker configuration and named pipe.**
   - Root cause: the restricted environment could not access my Docker Desktop configuration or engine pipe.
   - Resolution: I reran the read-only inspection from a local command session with Docker Engine access. Docker Desktop was running normally.
2. **`git status` reported that the workspace was not a repository.**
   - Root cause: Git had not been initialized.
   - Resolution: initialize only the clean `devops-practical/` directory after creating the source-of-truth log.
3. **No Git identity is configured.**
   - Impact: local files can be prepared and validated, but no commit will be created until the intended GitHub identity is confirmed.
4. **No WSL Linux distribution is installed.**
   - Resolution: prefer existing Docker images for Linux-specific testing instead of installing host tools.

### Repository initialization

Command:

```text
git init -b main
git status --short --branch
```

Output:

```text
Initialized empty Git repository in .../devops-practical/.git/
## No commits yet on main
?? .gitattributes
?? .gitignore
?? evidence/
```

The local repository is now initialized on `main`. No commit or remote operation was performed.

### Official references consulted

- Kubernetes manifest validation and dry-run behavior: https://kubernetes.io/docs/reference/kubectl/generated/kubectl_apply/
- Kubernetes probes: https://kubernetes.io/docs/concepts/workloads/pods/probes/
- NGINX configuration test switch: https://nginx.org/en/docs/switches.html
- SonarQube GitHub Actions integration: https://docs.sonarsource.com/sonarqube-server/devops-platform-integration/github-integration/adding-analysis-to-github-actions-workflow
- GitHub OIDC authentication to AWS: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- AWS Systems Manager Run Command: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-commands.html
- Trivy CI exit-code behavior: https://www.trivy.dev/docs/v0.60/guide/configuration/others/
- S3 Lifecycle management: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html

## Current status

- [x] Assessment requirements reviewed.
- [x] Local tools inventoried.
- [x] Repository documentation started.
- [x] Git repository initialized.
- [x] Implementation files created.
- [x] Local validation completed within the documented local scope.
- [ ] My manual review completed.
- [x] Git commit created.
- [x] GitHub remote configured.
- [x] GitHub branch pushed.

## Phase 2 - Kubernetes and Nginx implementation

### Files created

- `task-1-kubernetes/deployment.yaml`
- `task-1-kubernetes/service.yaml`
- `task-2-nginx/nginx.conf`

### Design decisions

- The Deployment uses the assessment-required `nginx:latest`, two replicas, explicit RollingUpdate settings, resource requests/limits, readiness/liveness probes, stable recommended labels, disabled service-account-token mounting, the runtime-default seccomp profile, and a reduced Linux capability set.
- `maxUnavailable: 0` and `maxSurge: 1` preserve availability for the two-replica workload during an update.
- The Service is explicitly `ClusterIP`, matching the requirement to expose NGINX internally.
- The Nginx file is a complete configuration rather than an isolated server fragment, so `nginx -t` can validate it directly.
- The redirect retains the request URI and returns HTTP 301. The application virtual host proxies to the required `127.0.0.1:3000` and forwards the original host, client address, forwarding chain, scheme, host, and port.

### Commands executed

```text
kubectl apply --dry-run=client --validate=false \
  -f task-1-kubernetes/deployment.yaml \
  -f task-1-kubernetes/service.yaml -o name

kubectl create --dry-run=client --validate=false \
  -f task-1-kubernetes/deployment.yaml \
  -f task-1-kubernetes/service.yaml -o name

docker run --rm \
  --mount type=bind,source=<repo>/task-2-nginx/nginx.conf,target=/etc/nginx/nginx.conf,readonly \
  nginx:latest nginx -t

docker run --rm \
  --mount type=bind,source=<repo>/task-1-kubernetes,target=/manifests,readonly \
  ghcr.io/yannh/kubeconform:v0.7.0 \
  -strict -summary -verbose -kubernetes-version 1.34.0 \
  /manifests/deployment.yaml /manifests/service.yaml
```

### Validation results

NGINX:

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Kubernetes schema validation:

```text
/manifests/service.yaml - Service nginx is valid
/manifests/deployment.yaml - Deployment nginx is valid
Summary: 2 resources found in 2 files - Valid: 2, Invalid: 0, Errors: 0, Skipped: 0
```

Validator image provenance:

```text
ghcr.io/yannh/kubeconform:v0.7.0
sha256:85dbef6b4b312b99133decc9c6fc9495e9fc5f92293d4ff3b7e1b30f5611823c
```

### Errors, root causes, and fixes

1. **Both local `kubectl` dry-run attempts tried to contact `http://localhost:8080` and failed.**
   - Root cause: `kubectl apply/create -f` still performs API discovery for resource mapping even with client dry-run and validation disabled. A safe local cluster context was not available.
   - Fix: used Kubeconform against Kubernetes 1.34 schemas for strict offline manifest validation.
   - Remaining limitation: schema validation cannot reproduce admission policies or controller-side semantic checks. A live cluster test remains documented but unclaimed.
2. **The first Kubeconform directory invocation produced no resource summary.**
   - Root cause: the validator invocation did not enumerate the mounted files as expected in this Docker Desktop path combination.
   - Fix: supplied both manifest filenames explicitly and enabled verbose output; both resources passed.

### Status

- [x] Kubernetes artifacts implemented.
- [x] Kubernetes YAML/schema validation completed.
- [ ] Kubernetes runtime Deployment/Service test completed on a live cluster.
- [x] Nginx configuration implemented.
- [x] Nginx syntax validation completed with the required image.
- [x] Nginx redirect and upstream behavior validated end to end.

## Phase 3 - Node.js application and Docker image

### My starting point

I supplied the following Dockerfile from my live technical interview and wanted its simple structure to remain recognizable:

```dockerfile
FROM node:latest

WORKDIR /app

COPY . .

RUN npm -I && npm build

entrypoint node server.js
```

This is my genuine starting point, not a deliberately introduced failure. My static review found the following issues before I attempted to submit it:

1. `npm -I` is not the intended clean-install command. The repository has a lock file, so `npm ci` is the deterministic choice and fails if the lock file and manifest disagree.
2. This plain Node.js application is not compiled and has no `build` script. Running `npm build` would therefore not represent a necessary application step.
3. Copying the entire context before dependency installation invalidates the dependency cache whenever source changes. The dependency files are copied first, then the remaining filtered context.
4. Shell-form `entrypoint node server.js` works differently from the JSON/exec form for signal handling. The final file keeps `ENTRYPOINT` but uses the exec form.
5. Port 3000 was not documented with `EXPOSE`.
6. The initial local sample stored the application at `src/server.js`. I moved it to the repository root so my original `node server.js` startup remains correct.

### Final design decision

I deliberately kept the Dockerfile small and retained my `node:latest`, `/app`, `COPY . .`, and `ENTRYPOINT` choices. I added only correctness, cache ordering, port documentation, and a non-root runtime. The application has a health-check endpoint for the CI/CD deployment check, but I did not add a complex in-image health check.

`node:latest` is a mutable tag and is not my production recommendation because it can change the Node major version and image contents between builds. I retained it initially because it was the choice I made during the interview. A production repository should normally select a supported LTS variant and pin its digest, with automated dependency updates.

### Files created or updated

- `task-3-docker/server.js`
- `task-3-docker/test/server.test.js`
- `task-3-docker/package.json`
- `task-3-docker/package-lock.json`
- `task-3-docker/Dockerfile`
- `task-3-docker/.dockerignore`
- `task-3-docker/sonar-project.properties`

### Validation plan

```text
cd task-3-docker
npm ci
npm test
docker build --pull --tag devops-practical-app:local .
docker run --detach --rm --name devops-practical-app-test --publish 127.0.0.1:3000:3000 devops-practical-app:local
docker inspect devops-practical-app:local
docker exec devops-practical-app-test id
Invoke-RestMethod http://127.0.0.1:3000/
Invoke-RestMethod http://127.0.0.1:3000/health
```

### Validation results

Host dependency install and tests:

```text
up to date, audited 1 package
found 0 vulnerabilities
tests 5
suites 2
pass 5
fail 0
```

Docker build:

```text
Base resolved: node:latest@sha256:f5d1cc40abc10c2843339a2134d07817cf33c405cb16bfd052b0ed790254c3a3
npm ci: up to date, audited 1 package; found 0 vulnerabilities
Image ID: sha256:aa638e7552285f0c9991b9ec0df31b6401fbaeb092b220134e3f7b46967c077f
Image size: 443807562 bytes
Build result: success
```

Container runtime:

```text
health={"status":"ok"}
root={"message":"DevOps practical application"}
uid=1000(node) gid=1000(node) groups=1000(node)
Node.js: v26.8.1
npm: 11.19.0
```

Nginx end-to-end behavior with Nginx and the revised application sharing a network namespace:

```text
redirect_status=301
redirect_location=http://www.abc.com/example?source=test
proxy_response={"message":"DevOps practical application"}
```

Both temporary validation containers were stopped and removed.

### Errors, root causes, and fixes

1. **PowerShell printed `The maximum redirection count has been exceeded` during the first redirect assertion.**
   - Root cause: `Invoke-WebRequest -MaximumRedirection 0` deliberately prevents following the required 301, but PowerShell also reports that expected condition as a non-terminating error.
   - Evidence: the same response object contained status `301` and location `http://www.abc.com/example?source=test`; the reverse proxy assertion also passed.
   - Fix: repeated the check with `curl`, which reported the 301 and `Location` directly without following it. Output matched the earlier assertion. This is a test-client behavior, not an Nginx configuration failure.

### Status

- [x] Application dependency installation completed.
- [x] Five application tests passed.
- [x] Docker image built from my interview-aligned Dockerfile.
- [x] Application and health endpoints passed.
- [x] Container confirmed to run as the non-root `node` user.
- [ ] Trivy HIGH/CRITICAL gate completed for the revised image (database download blocked locally; CI remains fail-closed).

### Trivy scan attempt 1

Command:

```text
docker run --rm \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  ghcr.io/aquasecurity/trivy:0.74.0 image \
  --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --no-progress \
  devops-practical-app:local
```

Result:

```text
Trivy requested a vulnerability database update and started downloading trivy-db:2.
No scan verdict was produced during the bounded wait.
The run was interrupted and exited 1.
```

This exit code is not recorded as a vulnerability-gate failure because scanning never began. The first container used only ephemeral cache storage, so the retry will use a dedicated local Docker volume to preserve the database download. The database download is external validation data and is not a repository artifact.

### Trivy database retry results

1. A retry used the dedicated `devops-practical-trivy-cache` volume with Trivy's default repository order. The first default endpoint, `mirror.gcr.io/aquasec/trivy-db:2`, remained active without placing a database in the cache and was stopped as inconclusive.
2. Official Trivy documentation confirmed that `--db-repository` can override the default endpoints and lists GHCR, Docker Hub, and public ECR locations.
3. A retry forced `ghcr.io/aquasecurity/trivy-db:2`. Docker network counters confirmed that data was moving, but too slowly to complete before Trivy's default timeout. Trivy exited 1 with:

```text
DB error: failed to download vulnerability DB
copy error: context deadline exceeded
```

This is still not a scan-policy verdict: the database initialization failed before image findings were evaluated. A final retry will use Aqua Security's documented public ECR database endpoint and an explicit higher timeout.

Official database-location reference: https://trivy.dev/docs/dev/configuration/db/

### Final local Trivy outcome

The public ECR retry used `--timeout 15m`. Network counters showed data transfer, but the database still did not complete before the deadline. Trivy exited 1 with the same `context deadline exceeded` database-initialization class. A follow-up inspection reported only 4 KB in the dedicated cache, confirming that no complete vulnerability database was available.

The inspection's optional file-detail command used GNU `find -printf`, but the Trivy image supplies BusyBox `find`, which does not support `-printf`; that command exited 1 after `du` had already reported the cache size. No cache content was changed.

Conclusion: local Trivy validation is **inconclusive because database acquisition failed**. It is not represented as a passing scan. The GitHub Actions stage remains fail-closed with Trivy 0.74.0, HIGH/CRITICAL severity, and exit code 1. A runner with normal registry throughput must complete this gate before any ECR push.

## Phase 4 - MySQL backup automation and S3 retention

### Requirement verification

The source assessment was re-read for Task 4 before implementation. It explicitly requires `mysqldump`, gzip compression, AWS CLI upload, database name and timestamp in the filename, important-operation/failure logging, non-zero failure exits, no hard-coded AWS credentials, environment-variable configuration, and seven-day retention with reproducible configuration.

The first extraction command used the host `python` and failed:

```text
ModuleNotFoundError: No module named 'docx'
```

Root cause: the ordinary host Python does not contain `python-docx`. No package was installed. The extraction was repeated successfully with the existing bundled document runtime, and paragraphs 178-223 confirmed the requirements above.

### Files created

- `task-4-backup/backup.sh`
- `task-4-backup/s3-lifecycle.json`
- `task-4-backup/retention-approach.md`

### Design decisions

- The script uses strict Bash mode and explicit checks for commands, required variables, input formats, each critical pipeline, archive integrity, upload success, and remote object size.
- The timestamp is generated at execution in UTC because it is an explicit filename requirement. No timestamp is fabricated or stored as local execution evidence.
- `MYSQL_DEFAULTS_FILE` optionally points to a protected MySQL option file. A database password is never placed in the script or command line.
- AWS CLI uses the ambient credential provider chain, allowing an EC2 IAM role or another short-lived identity. No access keys are accepted as script arguments.
- The upload explicitly requests S3-managed AES-256 encryption.
- The archive is staged under a mode-restricted temporary directory, checked with `gzip -t`, uploaded, verified with `head-object`, and then removed by an exit trap.
- S3 Lifecycle is the persistent seven-day retention control. The included configuration also covers versioned-object copies and incomplete multipart uploads.

### Required runtime permissions

The backup runtime needs:

- MySQL permissions needed to dump the selected schema objects, normally `SELECT`, `SHOW VIEW`, `TRIGGER`, and `EVENT` as applicable.
- `s3:PutObject` and `s3:GetObject` on `arn:aws:s3:::<bucket>/mysql-backups/*`. `GetObject` is required for the `head-object` verification.

Applying the lifecycle policy is a separate administrative action requiring `s3:PutLifecycleConfiguration` and `s3:GetLifecycleConfiguration` on the bucket.

### Validation status

- [x] Bash syntax validation completed.
- [x] ShellCheck completed.
- [x] Required-variable failure path completed.
- [x] Local dump/compression behavior completed.
- [ ] Real S3 upload completed.
- [x] Lifecycle JSON and AWS CLI command structure validated.

### Validation results

```text
ShellCheck after correction: exit 0, no findings
Bash syntax check: exit 0
Missing configuration test: [ERROR] Required environment variable is not set: MYSQL_HOST
Missing configuration exit: 1
Lifecycle JSON parse: passed
AWS CLI lifecycle input-shape validation: exit 0
```

I ran the dump/compression integration test against an isolated, non-published `mysql:8` server with one seeded record. I mocked AWS only at the command boundary because no assessment S3 bucket or cloud account was supplied. Output:

```text
mysqld is alive
[INFO] Creating compressed MySQL backup
[INFO] Backup archive created and validated
[INFO] Uploading backup archive to S3
[INFO] S3 upload verified
[INFO] Backup completed successfully
[TEST] compressed dump contains seeded database record
```

The test used collision-checked unique Docker names. The MySQL container, network, and mock-output volume were all removed after the test. This proves the real `mysqldump`/gzip pipeline and upload/verification control flow, but it does not claim a real S3 upload or IAM-policy test.

### Errors, root causes, and fixes

1. **The first ShellCheck run exited 1 with SC2153 for `MYSQL_HOST`.**
   - Root cause: the required configuration values were validated through Bash indirect expansion. Runtime evaluation was correct, but static analysis could not infer the assignment and treated the later reference as a possible misspelling.
   - Fix: normalize all five required values through explicit assignments before the common validation loop, making the data flow clear to ShellCheck and human reviewers.
2. **The first Docker integration-test command was rejected before execution.**
   - Root cause: it used fixed Docker network/volume names and unconditional cleanup. A pre-existing resource with the same name could theoretically have been removed.
   - Impact: no container, network, or volume was created or deleted by that attempt.
   - Fix: generate unique names, verify that they do not already exist, track which resources were successfully created, and clean up only those owned resources.
3. **The first Bash syntax-container command could not start `bash`.**
   - Root cause: the minimal `koalaman/shellcheck:stable` image contains ShellCheck but no Bash executable.
   - Fix: reused the already-cached `mysql:8` image, which contains Bash and the relevant MySQL client tooling. `bash -n` then exited 0.

### Official references consulted

- MySQL `mysqldump`: https://dev.mysql.com/doc/refman/8.4/en/mysqldump.html
- AWS CLI `s3 cp`: https://docs.aws.amazon.com/cli/latest/reference/s3/cp.html
- S3 Lifecycle configuration: https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html

## Phase 5 - GitHub Actions CI/CD

### Requirement verification

Task 5 paragraphs 225-277 were re-read from the source assessment. The required stages are checkout/Node/dependencies/tests, SonarQube, Docker build/tag, a fail-closed Trivy HIGH/CRITICAL scan, secure ECR push, deployment to one Ubuntu EC2 instance, and a health check that fails the pipeline when deployment or application health fails.

### Files created or updated

- `.github/workflows/ci-cd.yml`
- `task-5-cicd/github-actions.yml`
- `task-5-cicd/README.md`
- `task-3-docker/sonar-project.properties`

### Design decisions

- GitHub requires executable workflows under `.github/workflows/`; the identical Task 5 copy satisfies the requested assessment path.
- Tests and SonarQube complete before AWS authentication.
- The image is tagged with the Git commit SHA, scanned locally, and pushed only if Trivy reports no HIGH/CRITICAL findings.
- GitHub uses OIDC role assumption instead of long-lived AWS access keys.
- Deployment uses Systems Manager Run Command rather than SSH, so no inbound SSH port or private key is required.
- The EC2 instance pulls the exact SHA image using its instance role, replaces the named container, and performs the health check locally.
- The `production` GitHub Environment and job concurrency provide an approval/control point and prevent overlapping deployments to the one instance.
- No cloud execution is claimed because the required external services and identifiers were not supplied.

### Validation status

- [x] Workflow copies confirmed identical.
- [x] YAML and GitHub Actions semantic lint completed.
- [x] Embedded remote-command JSON construction tested.
- [x] All six generated remote shell commands passed Bash syntax parsing.
- [ ] SonarQube execution completed.
- [ ] ECR push completed.
- [ ] EC2/SSM deployment and health check completed.

### Local validation results

```text
Workflow copy diff: exit 0
Actionlint: exit 0, no findings
Actionlint image digest: sha256:b1934ee5f1c509618f2508e6eb47ee0d3520686341fec936f3b79331f9315667
Generated SSM command count: 6
AWS CLI input-shape/skeleton parse: exit 0
Remote Bash syntax parses: 6 of 6 passed
```

The SSM parameters used harmless placeholder account/repository/instance values. No AWS API request was made.

### Errors, root causes, and fixes

1. **Initial workflow inspection found collapsed shell continuation lines.**
   - Root cause: backslash-newline pairs were consumed while generating the YAML text, leaving valid but difficult-to-review one-line commands.
   - Fix: restored explicit multiline continuations in both workflow copies before semantic validation.
2. **The first standalone YAML parser attempt failed with `ModuleNotFoundError: No module named 'yaml'`.**
   - Root cause: the bundled document Python contains `python-docx` but not PyYAML.
   - Fix: did not install another host dependency; used the purpose-built Actionlint container, which parsed both YAML files and performed GitHub Actions semantic checks successfully.
3. **The first offline SSM-parameter check passed pretty-printed JSON to AWS CLI as multiple PowerShell arguments.**
   - Root cause: native-command output was captured as an array of lines in PowerShell. The workflow itself uses `file://` and was not affected.
   - Fix: generated compact JSON for the inline local test. It parsed into the expected six-command array.
4. **AWS CLI output-skeleton mode reported invalid generated response placeholders.**
   - Root cause: the CLI's synthetic SSM response used a nine-character command ID and zero-second timeout, which violate the service model. The error concerned generated output, not the submitted request parameters.
   - Fix: used input-skeleton mode for offline input parsing; it exited 0. Each of the resulting six remote commands was also parsed with `bash -n` and passed.
5. **Official action-metadata review found the Trivy version input was named incorrectly.**
   - Root cause: the initial workflow used `trivy-version`, while `aquasecurity/trivy-action@v0.36.0` defines the input as `version`. Actionlint validates GitHub workflow structure but did not fetch remote action metadata to flag the unknown input.
   - Fix: changed the input to `version: v0.74.0` in both copies. The action tag was corrected to the official `v0.36.0` form.
6. **Current official release review found newer Checkout and SonarQube action releases.**
   - Fix: updated Checkout to `v7.0.1`, Setup Node to the explicit `v6.4.0`, and SonarQube Scan Action to `v8.1.0`. GitHub-hosted `ubuntu-latest` supplies the v8 GPG prerequisites.

### Official action metadata verified

- Checkout changelog: https://github.com/actions/checkout/blob/main/CHANGELOG.md
- Setup Node releases: https://github.com/actions/setup-node/releases
- SonarQube Scan Action releases: https://github.com/SonarSource/sonarqube-scan-action/releases
- Trivy Action inputs: https://github.com/aquasecurity/trivy-action/blob/master/action.yaml
- AWS credentials action: https://github.com/aws-actions/configure-aws-credentials
- ECR login releases: https://github.com/aws-actions/amazon-ecr-login/releases

## Phase 6 - Troubleshooting approach

### Requirement verification

Task 6 paragraphs 279-320 were re-read before authoring. Each scenario must state the first check, why it comes first, commands/logs/tools, and conditional next checks rather than presenting one immediate fix.

### File created

- `evidence/troubleshooting-approach.md`

### Coverage

- Kubernetes Pod `Running` but `0/1` Ready.
- Healthy Pods inaccessible through a Kubernetes Service.
- Nginx returning 502 when the backend is expected on port 3000.
- Slow Ubuntu production server with an unavailable application.

The approach emphasizes impact scoping, evidence preservation, conditional diagnosis, reversible changes, post-fix verification, and avoiding destructive incident actions without understanding the target.

### Validation status

- [x] All four assessment scenarios confirmed present.
- [x] First-check/reason/commands/conditional-next structure confirmed for every scenario.
- [x] Command examples reviewed for destructive or credential-exposing behavior.

## Phase 7 - Root documentation and execution evidence

### Source requirement verification

Paragraphs 322-436 of the assessment were re-read. They require an AI tool/purpose/manual-review/validation disclosure, practical evidence without secrets, explicit explanations for unexecuted external components, a root README, and the final repository structure.

### Files created

- `README.md`
- `evidence/test-evidence/local-validation.md`

### Documentation decisions

- The root README is the operator-facing runbook; this implementation log remains the chronological source of truth.
- Actual local results are separated from cloud/runtime limitations.
- The README includes the required AI tool, purpose, manual-review, and validation details. My final manual review remains pending.
- Raw outputs containing wall-clock timestamps are not committed. Stable result fields, versions, digests, exit outcomes, and limitations are retained.
- The README includes prerequisites, task-by-task execution, configuration, permissions, assumptions, security controls, validation results, issues, and the pre-submission review checklist.

### Validation status

- [x] Required final-tree paths verified.
- [x] README requirement sections verified.
- [x] Evidence checked for secrets and sensitive infrastructure data.
- [x] Markdown links and referenced paths checked.

### Official references consulted

- Docker build-cache optimization: https://docs.docker.com/build/cache/optimize/
- npm clean installation: https://docs.npmjs.com/cli/commands/npm-ci/
- Node Docker Official Image tags: https://hub.docker.com/_/node/tags

## Phase 8 - GitHub publication preparation

### Publication scope and integrity constraints

- My publication target is `https://github.com/anshum940/rlogical-practical-assessment.git`.
- I configured the repository-local Git identity as `anshum940` / `anshumshankhdhar2910@gmail.com` and required a fresh GitHub device-code login before publication.
- I limited publication to the assessment repository files. The source DOCX, screenshots, extraction utilities, local review notes, credentials, caches, and generated runtime files remain outside this Git repository.
- I kept the repository limited to verified assessment work: my original Dockerfile draft, implemented corrections, actual errors, and documented validation limitations.
- Git records the real commit time. I omit wall-clock timestamps from the committed evidence for stable review, but I do not backdate or alter Git metadata.

### Pre-authentication Git audit

Commands:

```text
Get-Command gh
gh --version
git status --short --branch
git remote -v
git config --local --get user.name
git config --local --get user.email
```

Results:

```text
GitHub CLI: 2.93.0
Branch: main, no commits yet
Working tree: assessment files are untracked
Configured remotes: none
Repository-local user.name: not configured
Repository-local user.email: not configured
```

The nonzero combined command status came from the two expected missing `git config --get` values; it was not a repository failure. The next safe step is a read-only remote inspection before adding `origin`, authenticating, committing, or pushing.

### Read-only remote verification

Commands:

```text
git ls-remote --symref https://github.com/anshum940/rlogical-practical-assessment.git HEAD
git ls-remote --heads --tags https://github.com/anshum940/rlogical-practical-assessment.git
```

Result: both commands exited 0 and returned no references. The exact repository is reachable and empty, so configuring `origin` will not overwrite an existing branch or tag.

### GitHub Actions publication behavior

The first design triggered the complete SonarQube/AWS deployment chain on every push. That is correct only after external services are configured; with this new empty repository and no supplied SonarQube/AWS settings, the first push would have failed for a known configuration absence rather than a source defect.

The workflow now has two controlled modes:

- A push to `main` runs Node.js tests, configured SonarQube analysis, the Docker build, and the fail-closed Trivy gate.
- A manual `workflow_dispatch` run with `deploy=true` requires SonarQube and AWS settings, then performs ECR publication, SSM deployment, and the EC2-local health check. `deploy=false` performs validation only.

SonarQube is skipped transparently on non-deployment runs when its token or URL is absent. It is mandatory for a deployment run. AWS stages are never silently attempted or falsely reported when the required variables are unavailable.

Official behavior verified:

- GitHub workflow syntax and `workflow_dispatch`: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax
- GitHub Actions configuration variables; an unset `vars` value is an empty string: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables
- GitHub deployment triggers and protected environments: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments

### Updated workflow validation

Commands:

```text
git diff --no-index --exit-code -- .github/workflows/ci-cd.yml task-5-cicd/github-actions.yml
docker run --rm --volume <repository>:/repo --workdir /repo rhysd/actionlint:1.7.9 -color .github/workflows/ci-cd.yml task-5-cicd/github-actions.yml
```

Results:

```text
Workflow copy comparison: exit 0, identical
Actionlint 1.7.9: exit 0, no findings
Actionlint image digest: sha256:a0383f60d92601e2694e24b24d37df7b6a40bed7cedbc447611c50009bf02d94
```

My first Docker lint attempt failed before execution because that command session could not read the Docker Desktop configuration or access the Windows Docker named pipe. I reran it from a local session with Docker Engine access, and it passed. Git warned that the two untracked YAML working-tree files might later be checked out as CRLF; `.gitattributes` explicitly records YAML as LF in the Git object, so this was a Windows worktree conversion notice rather than a workflow defect.

### Local identity and remote configuration

Commands:

```text
git config --local user.name "anshum940"
git config --local user.email "anshumshankhdhar2910@gmail.com"
git remote add origin https://github.com/anshum940/rlogical-practical-assessment.git
git config --local --get user.name
git config --local --get user.email
git remote -v
git status --short --branch
```

Results:

```text
Repository-local user.name: anshum940
Repository-local user.email: anshumshankhdhar2910@gmail.com
origin fetch/push URL: https://github.com/anshum940/rlogical-practical-assessment.git
Branch: main, no commits yet
```

Only the nested assessment repository was configured; the global Git identity was not read, changed, or assumed. No authentication, commit, or push occurred in this step.

### Final repository regression - first attempt

The required-path check passed with 22 files present and zero missing, and the workflow-copy equality check passed. The combined regression then stopped while parsing `package-lock.json` with PowerShell `ConvertFrom-Json`.

```text
ConvertFrom-Json: The provided JSON includes a property whose name is an empty string;
this is only supported using the -AsHashTable switch.
```

Root cause: npm lockfile version 3 uses the valid empty-string property `packages[""]` for the root package. PowerShell's default object conversion cannot represent that property even though the JSON is valid and npm already consumed it successfully. Fix: rerun JSON parsing with `ConvertFrom-Json -AsHashtable`; no repository content needs to be changed for this tool-specific limitation.

The second regression attempt passed the 22-path inventory, workflow equality, and three-document JSON parse, then reported zero troubleshooting scenarios. Root cause: the check expected headings numbered `Scenario 1` through `Scenario 4`, while the authored document consistently uses `Scenario A` through `Scenario D`. Inspection confirmed the four requested topics are present. Fix: change the audit expression to match the document's actual A-D convention; no content change is required.

The corrected repository-only regression completed successfully:

```text
Required files: 22 present, 0 missing
Workflow copies: identical
JSON documents: 3 parsed
Troubleshooting scenarios: 4 found
High-risk secret signatures: 0 matches
Wall-clock timestamp signatures: 0 matches
Node.js tests: 5 passed, 0 failed
```

A later combined Docker regression was stopped after Kubeconform produced no output beyond its heading for approximately 90 seconds. Because Kubeconform retrieves schemas and the same manifests already passed strict Kubeconform 0.7.0 validation earlier, this is recorded as a stalled repeat attempt rather than a new validation failure or a replaced result. The remaining Docker checks are being run separately so one network-dependent validator cannot hide their outcomes. The app runtime container had not yet been created when the command was interrupted.

### Separated final Docker regression

The remaining checks were run separately and completed successfully:

```text
Pre-existing validation container: false
Nginx configuration test: successful
ShellCheck: exit 0, no findings
Backup script Bash parse: exit 0
Actionlint 1.7.9: exit 0, no findings
Application image build: successful
Resolved node:latest digest: sha256:f5d1cc40abc10c2843339a2134d07817cf33c405cb16bfd052b0ed790254c3a3
Health endpoint status: ok
Root endpoint message: DevOps practical application
Runtime UID: 1000
Container running during test: true
Validation container remaining after cleanup: false
```

The fresh build reused valid cache layers but resolved the base-image tag again. The exact temporary container name was checked before use, it was not allowed to replace an existing container, and it was removed in a `finally` cleanup. The earlier successful strict Kubernetes schema result remains the submitted evidence; the stalled repeat is disclosed alongside it.

### Staged inventory check - first attempt

Exactly 22 intended assessment files were staged, no unrelated file appeared, both workflow blobs had the same object ID, and `task-4-backup/backup.sh` had executable mode `100755`. `git diff --cached --check` reported an extra blank line at end-of-file in `.gitattributes`, `.gitignore`, both Kubernetes manifests, and `nginx.conf`. The runtime validators had accepted those files, but the repository hygiene check did not. The five trailing blank lines were removed and the files will be restaged before the commit. Windows also reported possible future CRLF working-tree conversion for non-LF-pinned text files; the submitted Git object uses the `.gitattributes` rules, including explicit LF for YAML, JSON, shell scripts, and Dockerfiles.

### Clean staged inventory

After restaging the five whitespace corrections, the repository passed the pre-commit checks:

```text
Staged files: 22
Untracked files outside staged inventory: 0
git diff --cached --check: exit 0
Git object line endings: LF for all 22 files
backup.sh mode: 100755
High-risk secret signatures: 0 matches
Wall-clock timestamp signatures: 0 matches
Different AI product-name signatures: 0 matches
```

The CRLF messages describe possible future Windows checkout conversion for text files without an explicit `eol` attribute; `git ls-files --eol` confirmed both index and current worktree content are LF at commit preparation time.

### Fresh GitHub authentication

`gh auth status` initially found three stored accounts with invalid tokens, including an unrelated active account. None was reused or deleted. A fresh GitHub web/device authorization was completed without storing its one-time code in this repository. GitHub CLI then reported `Logged in as anshum940`, and the independent read-only API check `gh api user --jq .login` returned exactly `anshum940`. The authentication token remained masked and is not present in repository content.

### Local commit and final remote safety check

The clean 22-file staged set was committed locally:

```text
Commit: a52ec4b0c0bb5ee4677bc654ab22f0f1bbbbc0bf
Subject: Complete DevOps practical assessment
Author name: anshum940
Author email: anshumshankhdhar2910@gmail.com
Files: 22
backup.sh mode: 100755
Post-commit working tree: clean
```

My first post-commit `git ls-remote origin` attempt could not resolve the alias. Git's Windows safe-directory protection rejected the local repository because its filesystem owner differed from the Windows account used for the network command. A local read-only check still showed the configured `origin`, identity, and clean repository correctly.

The exact-URL remote check was therefore repeated without reading local repository configuration; it exited 0 with no heads or tags, confirming the remote remained empty. The safe fix for publication is a one-command `git -c safe.directory=<exact-repository-path> push` override. This trusts only this exact repository for that Git invocation and does not modify global Git configuration. No force push will be used.

### GitHub publication and online workflow result

The two prepared commits were pushed without force. Git created remote branch `main` and configured the local branch to track `origin/main`. Read-only GitHub verification reported:

```text
Repository: anshum940/rlogical-practical-assessment
Visibility: PUBLIC
Default branch: main
Tested remote commit: 5ebd58575ec0aa0e3d706833ba8d7f7ec1311921
Workflow: DevOps Practical CI/CD
Run ID: 33202698261
Run event: push
```

Run: https://github.com/anshum940/rlogical-practical-assessment/actions/runs/33202698261

Actual job result:

```text
Test and SonarQube job: passed
Node.js install and tests: passed
SonarQube: transparently skipped because SONAR_TOKEN/SONAR_HOST_URL are not configured
Docker image build: passed
Trivy setup/database download: passed
Trivy OS result: 417 findings (361 HIGH, 56 CRITICAL)
Trivy Node-package result: 4 findings (4 HIGH, 0 CRITICAL)
Build/scan job: failed with exit 1 at the required security gate
ECR authentication/push: skipped
EC2/SSM deployment and health check: skipped
```

This is a real vulnerability verdict, unlike my earlier inconclusive local database-download attempts. The gate behaved as required: it returned nonzero and prevented publication/deployment. I did not hide any severity, add an ignore file, or weaken the exit code. The large result is associated with the mutable `node:latest` base that I initially chose; the sample application itself declares no third-party npm dependencies. I therefore decided to change to a supported minimal LTS/digest-pinned runtime and validate it through the same security gate.

This publication-result update changes documentation only. The follow-up commit uses GitHub's documented `[skip ci]` marker so it does not launch an identical push workflow after recording the completed run: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs

## Phase 9 - Security-gate remediation

### Direction and non-negotiable control

I kept SonarQube and Trivy in the workflow while correcting the pipeline. I did not change the Trivy `exit-code: 1` policy: the assessment explicitly requires HIGH/CRITICAL findings to fail, and forcing the scanner to return success while findings remain would be a false security result. I chose the valid remediation path of removing or upgrading vulnerable packages and re-running the same gate.

SonarQube also remains in the workflow. It cannot produce a real analysis result without the external `SONAR_HOST_URL` and `SONAR_TOKEN`; non-deployment runs continue to state that absence and skip the action rather than fabricate a result. A deployment run still requires SonarQube configuration.

### Base-image investigation

- Docker Scout 1.21.0 is installed, but its CVE command required a separate Docker Hub login. No unrelated account or token was requested or reused.
- Official Node.js sources identify Node 24 as LTS and document `node:24-alpine` as a small image variant. They also document a multi-stage pattern that copies the Node runtime into a minimal Alpine image without npm or Yarn.
- `node:24-alpine` resolved to digest `sha256:e67514e5d0f6c46656005e1b693b2ec9d52e80b641307de684d4a015ba7a4eaf`, Alpine 3.24.1, Node v24.20.0, and npm 11.19.0.
- Inspection showed the base's bundled npm still contains the same vulnerable package versions reported online: `brace-expansion` 5.0.7, `ip-address` 10.2.0, and `tar` 7.5.19. Merely changing the tag to Alpine would therefore not remove all Node-package findings.
- `alpine:3.24` resolved to digest `sha256:28bd5fe8b56d1bd048e5babf5b10710ebe0bae67db86916198a6eec434943f8b`.
- A fresh local Trivy database attempt reached less than one percent with a multi-hour transfer estimate and was interrupted. The `--timeout 2m` setting did not bound database acquisition as expected. The temporary cache is outside the repository. Online branch validation will use the same GitHub-hosted Trivy gate that completed previously.

Official references:

- Node.js release list: https://nodejs.org/en/blog/release
- Node Docker image variants: https://github.com/nodejs/docker-node/blob/main/README.md
- Node Docker smaller-image pattern without npm/Yarn: https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md#smaller-images-without-npmyarn
- Node Docker security responsibilities: https://github.com/nodejs/docker-node/blob/main/SECURITY.md

### Hardened image design

I created a separate local branch named `runtime-hardening` from clean `main`. My revised Dockerfile:

- Uses digest-pinned Node 24/Alpine 3.24 inputs.
- Runs `npm ci --omit=dev` only in the build stage.
- Copies the Node binary and application into a fresh digest-pinned Alpine runtime, so npm/Yarn and their vulnerable toolchain packages are absent from the final filesystem.
- Installs only the required C++ runtime library.
- Recreates UID/GID 1000, copies application files with non-root ownership, sets `NODE_ENV=production`, and retains `ENTRYPOINT ["node", "server.js"]`.

This is a genuine correction driven by the real security-gate result. It supersedes the earlier preference for `FROM node:latest` only as much as required to keep the mandatory gate meaningful and passing.

### Local hardened-image validation

The first build completed successfully. Alpine package-mirror throughput was slow while installing `libgcc`/`libstdc++`, but it progressed and did not fail. Results:

```text
Application tests: 5 passed, 0 failed
Docker build: passed
npm build-stage audit: 0 vulnerabilities
Health endpoint: ok
Root endpoint: DevOps practical application
Runtime UID: 1000
Runtime Node.js: v24.20.0
npm/npx/Yarn paths in final image: 0
Final image size: 52,762,648 bytes
Temporary validation container remaining: false
```

The local runtime result proves application behavior and removal of the vulnerable package-manager filesystem. It does not substitute for the mandatory Trivy result. I planned to commit and push the revision only to `runtime-hardening`, then manually dispatch the existing GitHub workflow with `deploy=false`. I would not move the Dockerfile change to `main` unless that branch passed the same online Trivy gate.

### Hardened image online attempt 1

Commit `2076f0e049dbba172a9884167fa78deabaf2e5c4` was pushed to the isolated `runtime-hardening` branch. Existing workflow run `33203937072` was manually dispatched against that ref with `deploy=false`, so AWS publication/deployment could not run.

Run: https://github.com/anshum940/rlogical-practical-assessment/actions/runs/33203937072

```text
Test and SonarQube job: passed
Application tests: passed
SonarQube: skipped because external configuration is absent
Docker build: passed
Trivy: failed with 2 HIGH, 0 CRITICAL
ECR/EC2 stages: skipped
```

Both findings are the same fixed OpenSSL issue, `CVE-2026-14456`, in runtime packages `libcrypto3` and `libssl3`. The installed version was `3.5.7-r0`; Trivy reported `3.5.8-r0` as the fixed version. In the next image revision, I explicitly installed/upgraded both packages to `3.5.8-r0` while preserving the same fail-closed scan. I did not introduce an ignore rule or severity change.

### Hardened image attempt 2 - local result

The image rebuilt successfully with both fixed packages. The health endpoint returned `ok`, the runtime UID remained 1000, and corrected package inspection reported:

```text
libcrypto3-3.5.8-r0: installed
libssl3-3.5.8-r0: installed
npm package-manager path: absent
npm library tree: absent
```

Two validation-command issues occurred after the successful build:

1. `apk info -v libcrypto3 libssl3` printed descriptions rather than installed version identifiers, so the assertion failed even though the build log showed the correct upgrades. The check was corrected to `apk list --installed`.
2. The first corrected `docker run` omitted `--entrypoint`, so the image's real `ENTRYPOINT ["node", "server.js"]` launched the service and treated the proposed `apk` words as application arguments. The command was interrupted. Its remaining disposable container was identified by exact ID, image, name, and running state, then removed explicitly. The corrected checks used `--entrypoint apk` and `--entrypoint sh` and passed.

These were test-harness errors, not application or image failures. They are retained here rather than rewritten as a clean first attempt.

### Hardened image online attempt 2 - passed

Commit `31e5cfb12a4f2c006dd2852facf72b05dd9b712b` was pushed to `runtime-hardening`, and existing workflow run `33204627031` was dispatched with `deploy=false`.

Run: https://github.com/anshum940/rlogical-practical-assessment/actions/runs/33204627031

```text
Test and SonarQube job: passed
Application tests: passed
SonarQube: skipped because external configuration is absent
Docker build: passed
Trivy Alpine 3.24.1 target: 0 vulnerabilities
Trivy Node-package target: 0 vulnerabilities
Trivy step and build/scan job: passed
AWS configuration/push/deployment: skipped because deploy=false
Overall workflow: passed
```

I did not change the security gate between the failed and passing runs. The hardened change was now eligible for fast-forward integration into `main`; I still required a final `main` push run before declaring the repository workflow green.

### Main integration and final online result

The clean `runtime-hardening` branch was fast-forwarded into local `main`; no merge rewrite, force push, or history replacement was used. Main was pushed from `aadb414` to `acd401e`, which triggered workflow run `33204905174` for the exact integrated commit.

Run: https://github.com/anshum940/rlogical-practical-assessment/actions/runs/33204905174

```text
Test and SonarQube job: passed
Application dependency install/tests: passed
SonarQube: transparently skipped because SONAR_TOKEN/SONAR_HOST_URL are absent
Docker image build: passed
Trivy HIGH/CRITICAL scan: passed
Trivy Alpine target: 0 vulnerabilities
Trivy Node-package target: 0 vulnerabilities
AWS/ECR/EC2 stages: skipped on the normal push event
Overall main workflow: passed
```

The temporary remote `runtime-hardening` branch was then deleted because all its commits are reachable from `main`; the matching local branch was deleted with Git's merged-branch safety check. Only `main` remains necessary. This final result is recorded in a documentation-only commit using `[skip ci]` to avoid an identical redundant scan; the earlier passing main run remains linked above.

## Phase 10 - Final documentation consistency check

### Objective

I performed a final consistency pass across the submitted Markdown so the README and evidence use the same terminology and clearly distinguish completed validation from work that still requires external infrastructure.

### Changes reviewed

- Standardized ownership and decision wording across the root README and evidence files.
- Simplified repetitive process language without changing technical evidence or limitations.
- Replaced the sample password text with the unmistakable placeholder `password=<mysql-password>`.
- Left application, infrastructure, workflow, and security-policy files unchanged.

### Commands executed

```text
rg -n -i "<third-person role and process patterns>" <repository> --glob "*.md"
rg -n -i "<high-risk credential patterns>" <repository>
rg -n -i "<excluded AI product names>" <repository>
rg -n "<wall-clock timestamp pattern>" <repository> --glob "*.md"
git diff --stat
git diff --check
```

### Results

- Reviewed Markdown files changed: 4.
- Non-Markdown files changed: 0.
- Inconsistent role/process wording: 0 matches.
- Excluded AI product names: 0 matches.
- High-risk secret signatures: 0 matches.
- Wall-clock timestamp signatures: 0 matches.
- README-referenced repository paths: 13/13 present.
- Workflow copies: identical.
- `git diff --check`: exit 0.

### Commit scope

Only the four reviewed Markdown files belong in this documentation-only update. The `[skip ci]` marker avoids repeating the already-passing code workflow for prose changes; the passing main workflow remains linked in Phase 9.

## Phase 11 - README alignment with the assessment

### Source requirement review

I reread the supplied assessment before changing the root README. It explicitly requires a brief overview, prerequisites, run/test instructions for every task, assumptions, encountered issues and resolutions, AI usage and review details, and enough information for another DevOps engineer to reproduce the work.

The first DOCX text-extraction attempt stopped on an embedded private-use icon because the Windows console used CP-1252 output. I reran the same read with UTF-8 output and successfully reviewed all assessment paragraphs. This was an extraction-display issue; the source document was not modified.

### README design decision

I changed the README from a generic operator-style runbook into a direct assessment submission:

- The opening now states what I implemented and the evidence produced.
- Each task explains my design, files, commands used, result, and limitation.
- Required setup and execution details remain, but they are presented as reproduction evidence rather than instructions to an unspecified reader.
- The generic pre-submission checklist was removed because it is not a required README section.
- Assumptions, real failures, corrections, external-service limitations, and AI usage remain explicit.
- Application, infrastructure, workflow, and security-policy files were not changed.

### Commands used for this review

```text
python -c "<python-docx paragraph and table extraction with UTF-8 output>" <assessment.docx>
rg <voice, requirement, credential, timestamp, and product-name patterns> README.md
git diff --check
```

### Validation status

- [x] All required README topics mapped to headings/content.
- [x] Reader-directed second-person wording removed: 0 matches.
- [x] Required task command coverage confirmed.
- [x] Local Markdown links verified: 16/16 present.
- [x] Malformed Markdown link lines: 0.
- [x] High-risk secret signatures: 0 matches.
- [x] Wall-clock timestamp signatures: 0 matches.
- [x] Excluded AI product names: 0 matches.
- [x] Workflow copies remain identical.
- [x] `git diff --check`: exit 0.
- [x] Final diff reviewed before commit.

## Phase 12 - Fresh-clone reproducibility audit

### Objective

I checked whether another DevOps engineer could clone the public repository and reproduce the assessment from the root README without relying on my working directory or conversation history.

### Audit approach

I cloned the published `main` branch into an isolated directory and treated that clone as the only available source. I checked the required file set, executable modes, local links, JSON, workflow copies, secret patterns, command coverage, and the locally executable validation paths.

The main checks included:

```text
git clone <public-repository-url> <isolated-directory>
git status --short
git ls-files --stage
npm ci
npm test
docker build --pull -t rlogical-practical-app:local .
docker run and curl endpoint checks
nginx -t and shared-network-namespace HTTP checks
kubeconform strict schema validation
shellcheck and bash -n
actionlint
```

### Issues found and decisions

1. **The README did not distinguish public access from authenticated workflow dispatch.**
   - Root cause: the optional repository-owner `gh workflow run` command could make GitHub authentication appear necessary for general reproduction.
   - Fix: stated that cloning, reading, local validation, and viewing the public run require no GitHub authentication. The GitHub CLI commands were removed entirely. Manual execution now uses the Actions UI for the repository owner, while independent execution uses a fork where the engineer controls workflow permissions.
2. **The README used `curl` without naming it in the prerequisite list.**
   - Root cause: it was treated as an assumed shell utility even though it is required by several checks.
   - Fix: added `curl` explicitly.
3. **The application example assumed host port 3000 was free.**
   - Root cause: the container port and host port were written as one fixed mapping. During the clean-clone audit, an unrelated local service already owned host port 3000 and returned its own page.
   - Fix: made the host side configurable with `APP_HOST_PORT`, bound it to `127.0.0.1`, and verified the application on an alternate free port. The container still listens on the required port 3000.
4. **The first request could race application startup.**
   - Root cause: `docker run --detach` returns before the Node process is necessarily ready to accept a connection.
   - Fix: added bounded curl retries for connection refusal before the endpoint assertion.
5. **The Nginx section reported its integration result but did not show the complete reproducible command sequence.**
   - Root cause: the concise README retained only the syntax command while detailed evidence retained the result.
   - Fix: added the exact shared-network-namespace test and cleanup commands to the root README.

### Official references used

- Docker port publishing: https://docs.docker.com/engine/network/port-publishing/
- Docker container network namespace: https://docs.docker.com/engine/network/
- curl retry behavior: https://curl.se/docs/manpage.html
- GitHub Actions manual workflow execution and permission requirement: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

### Validation results

- Dependency installation completed with zero reported npm vulnerabilities.
- All five Node.js tests passed.
- The Docker image built successfully from the submitted Dockerfile.
- With `APP_HOST_PORT=33000`, `/health` returned `{"status":"ok"}` and `/` returned `{"message":"DevOps practical application"}`.
- The running image reported Node.js `v24.20.0`.
- The Nginx integration check returned HTTP 301 with `Location: http://www.abc.com/example?source=test`.
- The Nginx proxy check returned `{"message":"DevOps practical application"}`.
- Both exact test containers and the temporary application image were removed after validation.
- README local links present: 20/20.
- Required updated README content present: all checks passed.
- JSON parse checks passed: 3/3 files.
- Workflow copies remained identical.
- Reader-directed second-person wording: 0 matches.
- Excluded product-name wording: 0 matches.
- Wall-clock timestamp patterns in the README: 0 matches.
- `git diff --check`: exit 0.

The first PowerShell JSON check failed because `package-lock.json` contains an empty property name and `ConvertFrom-Json` requires `-AsHashtable` for that valid npm structure. I repeated the same read-only validation with `ConvertFrom-Json -AsHashtable`; all three JSON files parsed successfully. This was a validator invocation issue, not invalid repository JSON.

The `workflow_dispatch` input was checked directly in both identical workflow files: `deploy` is a required Boolean with a safe default of `false`. I did not dispatch another workflow for this documentation-only change; the existing successful code-validating run is public and remains the execution evidence.

### Final result and next step

The README now explains public review, repository-owner UI execution, and independent execution from a fork without requiring GitHub CLI. It also handles a host-port collision, waits through the normal detached-container startup window, and includes the complete Nginx integration procedure. The two documentation files remain local working-tree changes pending final review and an explicit commit/push decision.

## Phase 13 - Reproducibility documentation publication

### Objective

I prepared the reviewed reproducibility corrections for publication to the public `main` branch. The authorized scope is limited to `README.md` and `evidence/implementation-log.md`.

### Pre-push checks and authentication

- Current branch: `main`.
- Remote: `https://github.com/anshum940/rlogical-practical-assessment.git`.
- Repository-local identity: `anshum940 <anshumshankhdhar2910@gmail.com>`.
- Files selected for publication: 2 documentation files.
- `git diff --check`: exit 0.
- A fresh GitHub web/device authorization was completed using an isolated configuration directory outside the repository.
- The authenticated identity was verified independently through the GitHub API as `anshum940`.
- The authentication token remained masked and is not stored in the repository.
- A fresh fetch showed `HEAD` and `origin/main` had no commits on either side of the comparison, so the remote had not changed before publication.

### Issue and safe resolution

The first elevated Git status check stopped with Git's `dubious ownership` protection because the managed sandbox owns the working tree under a different Windows SID from the authenticated desktop account. I did not weaken Git globally. Subsequent authenticated Git commands use a per-command `safe.directory` value restricted to this exact repository path.

### Publication procedure

Only the two reviewed documentation files will be staged. The staged diff will be checked again before creating the documentation commit and pushing `main`. After publication, the remote commit will be read back and compared with the local commit, and the isolated authentication directory will be removed.
