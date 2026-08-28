# Local Validation Evidence

This file summarizes checks that were actually executed. Wall-clock timestamps are omitted; no result was backdated or altered. Full commands, errors, fixes, image provenance, and decisions are in `../implementation-log.md`.

## Kubernetes schema

```text
/manifests/service.yaml - Service nginx is valid
/manifests/deployment.yaml - Deployment nginx is valid
Summary: 2 resources found in 2 files - Valid: 2, Invalid: 0, Errors: 0, Skipped: 0
```

Validator: `ghcr.io/yannh/kubeconform:v0.7.0` at digest `sha256:85dbef6b4b312b99133decc9c6fc9495e9fc5f92293d4ff3b7e1b30f5611823c`.

## Nginx

```text
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
redirect_status=301
redirect_location=http://www.abc.com/example?source=test
proxy_response={"message":"DevOps practical application"}
```

## Node.js and Docker

```text
tests 5
suites 2
pass 5
fail 0

health={"status":"ok"}
root={"message":"DevOps practical application"}
uid=1000(node) gid=1000(node) groups=1000(node)
Node.js: v26.8.1
npm: 11.19.0
```

The validation build resolved `node:latest` to digest `sha256:f5d1cc40abc10c2843339a2134d07817cf33c405cb16bfd052b0ed790254c3a3`. Because the submitted tag is mutable, a later build can resolve differently.

## Backup automation

```text
ShellCheck after correction: exit 0, no findings
Bash syntax check: exit 0
[ERROR] Required environment variable is not set: MYSQL_HOST
Missing configuration exit: 1
Lifecycle JSON parse: passed
AWS CLI lifecycle input-shape validation: exit 0
```

Isolated MySQL integration output:

```text
mysqld is alive
[INFO] Creating compressed MySQL backup
[INFO] Backup archive created and validated
[INFO] Uploading backup archive to S3
[INFO] S3 upload verified
[INFO] Backup completed successfully
[TEST] compressed dump contains seeded database record
```

The dump and gzip operations used a real temporary MySQL 8 server. Only the AWS command boundary was mocked; no real S3 upload or IAM authorization is claimed.

## GitHub Actions

```text
Workflow copy diff: exit 0
Actionlint 1.7.9: exit 0, no findings
Generated SSM command count: 6
AWS CLI input-skeleton parse: exit 0
Remote shell commands parsed: 6
```

Pushes to `main` run tests, configured SonarQube analysis, image build, and the fail-closed scan. ECR/EC2 stages require a manual run with `deploy=true`; that mode first requires SonarQube and all documented AWS settings. No SonarQube analysis, ECR push, SSM command, EC2 replacement, or cloud health check was executed because those external resources were not provided.

The final repository audit found 22 required files with none missing, identical workflow copies, three parseable JSON documents, all four troubleshooting scenarios, zero high-risk secret signatures, and zero wall-clock timestamp signatures. A final application image build, endpoint test, UID check, Nginx test, ShellCheck, Bash parse, and Actionlint run passed; the temporary application container was removed afterward.

## Trivy

Trivy 0.74.0 was invoked with `--severity HIGH,CRITICAL --exit-code 1` against `devops-practical-app:local`. Database downloads were attempted from the default mirror, Aqua Security GHCR, and Aqua Security public ECR. The mirror stalled, GHCR exceeded the default deadline, and public ECR exceeded an explicit 15-minute deadline.

Final error category:

```text
DB error: failed to download vulnerability DB
copy error: context deadline exceeded
```

The dedicated cache remained 4 KB, so it does not contain a complete database. No image scan verdict was produced. This result is neither a clean scan nor a HIGH/CRITICAL finding. The GitHub workflow retains the required fail-closed Trivy action; it must complete successfully on a runner with working registry throughput before ECR push is allowed.
