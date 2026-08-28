# Implementation Log

This file is the chronological source of truth for the assessment. It records decisions, commands, actual results, errors, fixes, limitations, and remaining work. Wall-clock timestamps are intentionally omitted; the order of entries preserves the work sequence.

## Objective

Produce a small, reproducible DevOps assessment repository containing:

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
- A final human review is required before submission so the candidate can explain every decision.

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
   - Root cause: the default sandbox could not access the user's Docker Desktop configuration or engine pipe.
   - Resolution: reran the read-only Docker inspection with approved local-engine access. Docker Desktop is running normally.
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
- [ ] Candidate manual review completed.
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

### Candidate starting point

The candidate supplied the following Dockerfile from the live technical interview and requested that its simple structure remain recognizable:

```dockerfile
FROM node:latest

WORKDIR /app

COPY . .

RUN npm -I && npm build

entrypoint node server.js
```

This is a genuine candidate-provided starting point, not a deliberately introduced failure. Static review found the following issues before attempting to submit it:

1. `npm -I` is not the intended clean-install command. The repository has a lock file, so `npm ci` is the deterministic choice and fails if the lock file and manifest disagree.
2. This plain Node.js application is not compiled and has no `build` script. Running `npm build` would therefore not represent a necessary application step.
3. Copying the entire context before dependency installation invalidates the dependency cache whenever source changes. The dependency files are copied first, then the remaining filtered context.
4. Shell-form `entrypoint node server.js` works differently from the JSON/exec form for signal handling. The final file keeps `ENTRYPOINT` but uses the exec form.
5. Port 3000 was not documented with `EXPOSE`.
6. The initial local sample stored the application at `src/server.js`. It was moved to repository root so the candidate's original `node server.js` startup remains correct.

### Final design decision

The final Dockerfile deliberately remains small and retains the candidate's `node:latest`, `/app`, `COPY . .`, and `ENTRYPOINT` choices. Only correctness, cache ordering, port documentation, and non-root runtime were added. A health-check endpoint exists in the application for the CI/CD deployment check, but no complex in-image health check is added.

`node:latest` is a mutable tag and is not the production recommendation because it can change the Node major version and image contents between builds. It is retained here as the candidate's explicit assessment choice. A production repository should normally select a supported LTS variant and pin its digest, with automated dependency updates.

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
- [x] Docker image built from the candidate-aligned Dockerfile.
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

The dump/compression integration test used an isolated, non-published `mysql:8` server with one seeded record. AWS was intentionally mocked only at the command boundary because no assessment S3 bucket or approved cloud account was supplied. Output:

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
- The AI disclosure identifies an OpenAI AI coding assistant and accurately states that final candidate review is pending. It does not claim the work was completed without AI.
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

### User direction and integrity boundary

- The requested target is `https://github.com/anshum940/rlogical-practical-assessment.git`.
- The user supplied the repository-local Git identity `anshum940` / `anshumshankhdhar2910@gmail.com` and requested a fresh GitHub device-code login before publication.
- Publication is limited to the assessment repository files. The source DOCX, screenshots, extraction utilities, local review notes, credentials, caches, and generated runtime files are outside this Git repository and must not be staged.
- The repository will retain its accurate AI-assistance disclosure, the candidate-supplied Dockerfile draft, real corrections, real errors, and actual validation limitations. No authorship concealment, fabricated mistake, fabricated output, altered time, or false candidate-review claim will be introduced.
- A Git push records its real commit time. The committed evidence omits wall-clock timestamps for stable review, but Git metadata will not be backdated or altered.

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

The first Docker lint attempt failed before execution because the restricted process could not read Docker Desktop configuration or access the Windows Docker named pipe. It was rerun with approved local-engine access and passed. Git warned that the two untracked YAML working-tree files may be checked out as CRLF later; `.gitattributes` explicitly records YAML as LF in the Git object, so this is a Windows worktree conversion notice rather than a workflow defect.

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

### AI tool naming review

The user requested vendor-level wording for the AI tool disclosure. No different product was claimed. The tool description is now `OpenAI AI coding assistant`, while the purpose, candidate-review requirement, corrections, validation method, and limitations remain unchanged. AI assistance is still explicitly disclosed as required by the assessment.

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

The first post-commit `git ls-remote origin` attempt could not resolve the alias. Inspection found Git's Windows safe-directory protection rejecting the local repository only in the approved network process: the workspace is owned by the restricted workspace account, while the network process runs as the interactive Windows account. The normal restricted process still sees the configured `origin`, identity, and clean repository correctly.

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

This is a real vulnerability verdict, unlike the earlier inconclusive local database-download attempts. The gate behaved as required: it returned nonzero and prevented publication/deployment. No severity was hidden, no ignore file was added, and the exit code was not weakened. The large result is associated with the candidate-requested mutable `node:latest` base; the sample application itself declares no third-party npm dependencies. Changing to a supported minimal LTS/digest-pinned runtime is the recommended security correction, but that change requires an explicit candidate decision because retaining `FROM node:latest` was a stated requirement.

This publication-result update changes documentation only. The follow-up commit uses GitHub's documented `[skip ci]` marker so it does not launch an identical push workflow after recording the completed run: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs
