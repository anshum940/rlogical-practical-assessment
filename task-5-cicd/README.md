# CI/CD Configuration

The executable workflow is stored at `.github/workflows/ci-cd.yml`. The required assessment copy is `task-5-cicd/github-actions.yml`; both files must remain identical.

## Pipeline

1. Check out the repository with full history, configure Node.js 24, run `npm ci`, and execute the tests.
2. Analyze `task-3-docker` with SonarQube when `SONAR_TOKEN` and `SONAR_HOST_URL` are configured. A requested deployment fails before publishing if either value is missing.
3. Build the Docker image and tag it with the immutable Git commit SHA.
4. Scan OS and application packages with Trivy 0.74.0. Any HIGH or CRITICAL finding exits 1, so the image is not pushed.
5. Obtain short-lived AWS credentials through GitHub OIDC, log in to ECR, and push the SHA-tagged image.
6. Send a deployment command to one managed Ubuntu EC2 instance through AWS Systems Manager Run Command.
7. Replace the application container, test `http://127.0.0.1:3000/health` on the instance, and fail the job if deployment or health checking fails.

Pushes to `main` run tests, optional configured SonarQube analysis, the Docker build, and the fail-closed Trivy gate. ECR publication and EC2 deployment run only when an operator starts **Run workflow** with `deploy=true`; this prevents a predictable failed or accidental deployment before external infrastructure is configured. A manual run with `deploy=false` repeats the non-deployment checks.

## GitHub configuration

Create these Actions variables:

- `SONAR_HOST_URL`: HTTPS URL of the SonarQube server.
- `AWS_ROLE_TO_ASSUME`: ARN of the GitHub OIDC deployment role.
- `AWS_REGION`: region containing ECR, Systems Manager, and the instance.
- `ECR_REPOSITORY`: existing private ECR repository name.
- `EC2_INSTANCE_ID`: Systems Manager-managed Ubuntu instance ID.

Create this Actions secret:

- `SONAR_TOKEN`: project-analysis token with only the required SonarQube scope.

Configure the `production` GitHub Environment with appropriate reviewers. Do not add AWS access keys: `aws-actions/configure-aws-credentials` exchanges GitHub's OIDC token for a short-lived role session.

## AWS prerequisites

The GitHub OIDC role needs:

- `ecr:GetAuthorizationToken`.
- ECR upload actions on the selected repository: `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `ecr:PutImage`.
- `ssm:SendCommand` scoped to the target instance and the `AWS-RunShellScript` document.
- `ssm:GetCommandInvocation` for deployment status.

The EC2 instance must:

- Be registered as a Systems Manager managed node with an instance role equivalent to `AmazonSSMManagedInstanceCore`.
- Have AWS CLI, Docker Engine, and `curl` installed.
- Have outbound access to the regional ECR and Systems Manager endpoints, directly or through VPC endpoints.
- Use an instance role that can call `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer`, and `ecr:BatchCheckLayerAvailability` for the repository.
- Allow the intended clients to reach TCP port 3000. The health check itself runs locally on the instance and does not require a public IP.

## Vulnerability policy and assumptions

- Both fixable and currently unfixed HIGH/CRITICAL OS or Node.js library findings fail the pipeline.
- No `.trivyignore` exceptions are included. A future exception must identify the CVE, owner, risk acceptance, compensating control, and expiry date.
- The first candidate-aligned `node:latest` build failed the real gate with HIGH/CRITICAL findings. The final Dockerfile uses a digest-pinned Node 24 LTS builder and digest-pinned Alpine runtime without npm/Yarn, then installs the exact fixed OpenSSL package version reported by Trivy. Pins must be updated through reviewed, scanned changes rather than silently floating.
- The ECR push cannot run until the scan passes.

## Deployment behavior

Systems Manager avoids inbound SSH and a long-lived SSH key. The remote command logs in to ECR with the EC2 instance role, pulls the exact SHA tag, replaces the named container, and retries the local health endpoint for up to one minute. Shell errors, Docker errors, SSM failures, and health failures all produce a non-zero workflow result.

This is intentionally a single-instance deployment because the assessment requires one EC2 server. Replacing the container can cause brief downtime. A production highly available service should use multiple instances behind a load balancer or a managed orchestrator and a rolling or blue/green deployment.

Cloud execution has not been claimed because no assessment AWS account, ECR repository, EC2 instance, OIDC role, or SonarQube server was supplied.

## Official references

- GitHub OIDC with AWS: https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws
- AWS Systems Manager Run Command: https://docs.aws.amazon.com/systems-manager/latest/userguide/running-commands.html
- Amazon ECR authentication: https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html
- SonarQube GitHub Actions integration: https://docs.sonarsource.com/sonarqube-server/devops-platform-integration/github-integration/adding-analysis-to-github-actions-workflow
- Trivy exit-code policy: https://trivy.dev/docs/latest/configuration/others/
