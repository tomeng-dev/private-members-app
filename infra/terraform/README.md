# Terraform — Private Members (AWS us-east-1)

Ready-to-apply IaC for staging/production. **Do not apply without client AWS credentials.**

## Apply order

1. Ensure Route 53 hosted zone for `domain_name` exists.
2. Ensure GitHub OIDC provider exists in the account (`token.actions.githubusercontent.com`), or create from `../iam`.
3. `cd terraform && terraform init`
4. `terraform plan -var-file=envs/staging.tfvars`
5. `terraform apply -var-file=envs/staging.tfvars` (after review)
6. Confirm SES email identity / leave sandbox.
7. Store additional secrets (Firebase JSON, Stripe links) in Secrets Manager.
8. Point GitHub Actions OIDC role ARN at Environments.
9. Repeat for production with `envs/production.tfvars`.

## What this creates

VPC (public/private), NAT, ALB+EB (Node 24, health `/api/health`, 3600s idle for Socket.IO), RDS MySQL encrypted, S3 (media/verification/web/admin), CloudFront + security headers CSP, ACM+Route53, SES domain, Secrets Manager, CloudWatch alarms + SNS, AWS Budgets, GitHub Actions deploy role.

## Validate locally (no AWS)

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```
