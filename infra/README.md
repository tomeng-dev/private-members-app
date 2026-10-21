# Infrastructure

- `terraform/` — full AWS stack (VPC, EB Node 24, RDS MySQL, S3, CloudFront+CSP headers, SES, Secrets Manager, alarms, Budgets, GitHub OIDC). See `terraform/README.md`.
- `iam/` — IAM policy JSON templates from the CI/CD guide.

**Validate (no AWS credentials required for syntax):**

```bash
cd terraform && terraform init -backend=false && terraform validate
```

Do **not** `terraform apply` from this delivery box.
