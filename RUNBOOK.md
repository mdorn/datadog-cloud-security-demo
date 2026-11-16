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

## Building the remediation workflows (one-time, in the UI)
The Datadog provider manages workflows through `datadog_workflow_automation`, but the first version of each is built in the UI, where Datadog's own action pickers fill in the Slack, Jira and AWS connection parameters. After that the exported JSON lives in `datadog/workflows/` and Terraform manages it.

Prerequisites (already done in the sandbox org): the Datadog Slack app is connected to workspace **Datadog**, the Jira integration (`textmethod.atlassian.net`) is active, and connection **`cspm-remed-demo-aws`** exists (Terraform `infra/datadog-iam/`).

### Workflow 1: `cspm-remed-demo-s3-block-public-access`
1. **Actions → Workflow Automation → New Workflow.** Name it `cspm-remed-demo-s3-block-public-access`, add tags `env:demo`, `team:web`, `service:demo-app`, and click Create.
2. **Add Trigger → Security.**
3. **Add step → Data Transformation → JS Function**, named `Parse_finding`, with this script:
   ```js
   const f = $.Source.securityFinding || {};
   const attrs = f.attributes || {};
   const tags = f.tags || attrs.tags || [];
   const ruleId = _.get(f, 'rule.id') || _.get(attrs, 'rule.id') || _.get(f, 'rule_id') || '';
   const regionTag = tags.find(t => t.startsWith('region:'));
   return {
     expected: ruleId === 'hkp-p6b-f7w',
     ruleId,
     bucket: attrs.resource_name || f.resource || '',
     region: regionTag ? regionTag.split(':')[1] : 'us-east-2',
     title: attrs.title || _.get(f, 'rule.name') || 'S3 bucket Block Public Access disabled',
     link: f.datadogLink || attrs.datadog_link || '',
   };
   ```
4. **Add step → Logic → If condition**, named `Is_expected_finding`: `{{ Steps.Parse_finding.data.expected }}` **is equal to** `true`. Leave the false branch empty, so the workflow ends.
5. On **true**: **Slack → Make a decision**, named `Approve_block_public_access`. Workspace **Datadog**, channel **#mdorn-demo-public**.
   - Prompt: `:rotating_light: *{{ Steps.Parse_finding.data.title }}*\nBucket: \`{{ Steps.Parse_finding.data.bucket }}\` ({{ Steps.Parse_finding.data.region }})\nBlock all public access on this bucket?`
   - Choices: **Approve** and **Reject**.
6. On **Approve**: **AWS → S3 → Block public access**, named `Block_public_access`.
   - Connection: `cspm-remed-demo-aws`.
   - Region: `{{ Steps.Parse_finding.data.region }}`
   - Bucket: `{{ Steps.Parse_finding.data.bucket }}`
7. Then **Slack → Send message**, named `Confirm_fixed`, to the same channel: `:white_check_mark: Block Public Access enabled on \`{{ Steps.Parse_finding.data.bucket }}\`. The finding clears after the next scan.`
8. Then **Jira → Create issue**, named `Create_jira_issue`. Account `textmethod.atlassian.net`, project **KAN**, issue type **Task**.
   - Summary: `[cspm-remed-demo] {{ Steps.Parse_finding.data.title }}: {{ Steps.Parse_finding.data.bucket }}`
   - Description: `Remediated via Datadog Workflow (approved in Slack). Bucket Block Public Access enabled. Finding: https://app.datadoghq.com{{ Steps.Parse_finding.data.link }}`
9. On **Reject**: **Slack → Send message**, named `Rejected`: `:no_entry: Remediation rejected for \`{{ Steps.Parse_finding.data.bucket }}\`. No change made.`
10. Optionally, on the AWS step's **error** branch, add Slack → Send message: `:x: Block public access failed: {{ Steps.Block_public_access }}`.
11. **Save → Publish.** Then **⋯ → Export** (JSON) and save the file as `datadog/workflows/cspm-remed-demo-s3-block-public-access.json`.

### Workflow 2: `cspm-remed-demo-sg-revoke-open-ssh`
Same shape as workflow 1, with these differences:
- **`Parse_finding` script:**
  ```js
  const f = $.Source.securityFinding || {};
  const attrs = f.attributes || {};
  const ruleId = _.get(f, 'rule.id') || _.get(attrs, 'rule.id') || _.get(f, 'rule_id') || '';
  const arn = f.externalId || attrs.external_id || attrs.resource_id || '';
  const m = arn.match(/^arn:aws:ec2:([^:]+):\d+:security-group\/(sg-[0-9a-f]+)$/);
  return {
    expected: ruleId === 'tch-c9p-gh4' && !!m,
    ruleId, arn,
    region: m ? m[1] : 'us-east-2',
    groupId: m ? m[2] : '',
    groupName: attrs.resource_name || f.resource || '',
    title: attrs.title || _.get(f, 'rule.name') || 'Security group allows SSH from 0.0.0.0/0',
    link: f.datadogLink || attrs.datadog_link || '',
  };
  ```
- **Decision prompt:** `Revoke inbound tcp/22 from 0.0.0.0/0 on \`{{ Steps.Parse_finding.data.groupName }}\` ({{ Steps.Parse_finding.data.groupId }})?`
- **Approve action: AWS → EC2 → Revoke security group ingress**, named `Revoke_open_ssh`.
  - Connection: `cspm-remed-demo-aws`
  - Region: `{{ Steps.Parse_finding.data.region }}`
  - Group ID: `{{ Steps.Parse_finding.data.groupId }}`
  - IP permissions:
    ```json
    [{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]
    ```
- **Confirm and Jira text:** use the group name and ID instead of the bucket.
- **Export to:** `datadog/workflows/cspm-remed-demo-sg-revoke-open-ssh.json`.

> The `Parse_finding` scripts read several possible field names, because the exact shape of `$.Source.securityFinding` is only confirmed on the first real run. Check that run's `Parse_finding` output, then simplify the script.
