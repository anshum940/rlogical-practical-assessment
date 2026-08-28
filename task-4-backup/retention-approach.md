# Backup Retention

The script keeps the backup only in a restricted temporary directory while it creates, validates, uploads, and verifies the archive. The temporary directory is removed on success or failure. Amazon S3 is therefore the only persistent backup location.

The included `s3-lifecycle.json` expires current objects under `mysql-backups/` after seven days. It also expires noncurrent versions after seven days when bucket versioning is enabled and aborts incomplete multipart uploads after one day.

Apply the lifecycle configuration from the repository root:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket "$S3_BUCKET" \
  --lifecycle-configuration file://task-4-backup/s3-lifecycle.json \
  --region "$AWS_REGION"
```

Verify it:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket "$S3_BUCKET" \
  --region "$AWS_REGION"
```

The identity applying this configuration needs `s3:PutLifecycleConfiguration` and `s3:GetLifecycleConfiguration` on the bucket. The runtime identity used by `backup.sh` does not need those administrative permissions.

If `S3_PREFIX` is changed from the default `mysql-backups`, update the lifecycle policy prefix before applying it. S3 Lifecycle expiration is asynchronous; eligible objects may remain visible for a short period after reaching the expiration age.
