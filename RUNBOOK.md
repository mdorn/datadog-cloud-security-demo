# RUNBOOK: cspm-remed-demo

> Work in progress. Demo-day checklist, scan timing and break/reset steps are added in later phases.

## Prerequisites
- `aws` CLI with profile `default` pointed at account `897722680419`
- Terraform >= 1.5
- `DD_API_KEY` and `DD_APP_KEY` exported for the Datadog sandbox org (US1, datadoghq.com)
- The app key in `DD_APP_KEY` must have **Actions API Access** enabled. Set it in the Datadog UI: Organization Settings → Application Keys → the key → Actions API Access. It can't be done by API or Terraform, and without it `datadog_app_key_registration` fails with "actions API access is not enabled on this application key".
- `export TF_VAR_datadog_app_key_id=$(scripts/dd-app-key-id.sh)` (the key ID, not its value)
- `export TF_VAR_dd_api_key="$DD_API_KEY"` for `infra/vuln-host/`. It's a write-only value, so it never lands in plan or state. To rotate the key, bump `dd_api_key_version`.
- Run `scripts/preflight.sh` before any AWS or Terraform command

## State
Terraform state is **local** to each stack directory and gitignored (the repo is public).
Don't commit `*.tfstate`, and don't delete it: losing state orphans resources.

## Ownership
| Component | Owner | Notes |
|---|---|---|
| Datadog AWS integration (Datadog side) | Terraform `datadog/` | Imported. external_id isn't managed in code. |
| `DatadogIntegrationRole` + permission policies | CloudFormation `DatadogIntegration*`, `DatadogAttachIntegrationPermissions` | Not managed by Terraform |
| Agentless scan options (Datadog side) | Terraform `datadog/` | Imported |
| Agentless scanner (VPC, ASG, delegate role) | CloudFormation `DatadogAgentlessIntegration` | Self-hosted mode; the ASG scales from 0 |
| Workflow Automation connection + role | Terraform `infra/datadog-iam/` | `cspm-remed-demo-aws` / `cspm-remed-demo-workflow-automation` |
| GitHub OIDC provider + role | Terraform `infra/datadog-iam/` | `cspm-remed-demo-github-actions`, main branch only |
| Demo VPC, subnet, IGW, locked-down default SG | Terraform `infra/network/` | `cspm-remed-demo-vpc` |
| Intentional misconfigs (S3, SG, IAM user) | Terraform `infra/vulnerable/` | See `DEMO_FINDINGS.md` |
| Vulnerable host, ECR repo, Agent API key parameter, redeploy SSM document | Terraform `infra/vuln-host/` | `cspm-remed-demo-vuln-host`, `cspm-remed-demo-app` |
| App image builds | GitHub Actions `.github/workflows/build-push.yml` | Push to `main` touching `app/**` → build, push `<sha12>`, redeploy |

## Host access and redeploy
- Shell: `aws ssm start-session --target <instance-id>` (there are no inbound rules and no SSH).
- Redeploy: `make deploy-image [TAG=<sha12>]` runs SSM document `cspm-remed-demo-redeploy`. The document only writes the tag and restarts `cspm-remed-demo-app.service`.
- Bootstrap log: `/var/log/cloud-init-output.log`. Agent: `sudo datadog-agent status`.
- The app container runs with `--network none --read-only --cap-drop ALL`, so it has no network path even though it carries Log4Shell.

## Workflow role scoping
| Action | Scope |
|---|---|
| s3:Get/PutBucketPublicAccessBlock | `arn:aws:s3:::cspm-remed-demo-*` |
| ec2:DescribeSecurityGroups | `*` (AWS doesn't support resource-level permissions for Describe*) |
| ec2:RevokeSecurityGroupIngress | security groups in us-east-2/897722680419, in the demo VPC (`ec2:Vpc`), where tag `Name` matches `cspm-remed-demo-*` (SG ARNs use random IDs, so they can't be scoped by name) |

## Teardown (outline; ask before running any destroy)
1. Datadog notification rules and workflows (Phase 4), then `infra/vuln-host/` (`terraform destroy`; ECR has `force_delete`).
2. `infra/vulnerable/`: `terraform destroy` (the bucket has `force_destroy`, so the placeholder object goes with it).
3. `infra/datadog-iam/`: `terraform destroy` removes the connection, the roles, the OIDC provider and the app key registration. Run this **before** `infra/network/`, because it looks up the demo VPC.
4. `infra/network/`: `terraform destroy`.
5. `datadog/`: use `terraform state rm` on both resources rather than destroy, so the pre-existing integration and scan options stay in place.
