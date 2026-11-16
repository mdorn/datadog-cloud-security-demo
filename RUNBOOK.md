# RUNBOOK: cspm-remed-demo

Demo storyline: **detect → prioritize → route → remediate → verify** with Datadog Cloud Security.

## Make targets
| Target | What it does | Changes things? |
|---|---|---|
| `make status` | Account check; whether the bucket, security group and IAM user are each armed or fixed; host and running image tag/digest; newest ECR images; latest Actions run | No |
| `make break` | `terraform plan` on `infra/vulnerable/`, summary, **y/N**, apply; then makes sure the baseline image has the `baseline` ECR tag, redeploys `DEMO_BASELINE_TAG`, and shows status | Yes, after confirmation |
| `make reset` | Same re-arm as `break`; then, if `app/pom.xml` on `main` differs from the baseline, a `reset/…` branch plus a revert PR (**y/N**); redeploys the baseline image; prints the Jira JQL and link for open demo issues | Yes, after confirmation |
| `make deploy-image [TAG=…]` | Deploys an image tag to the host through the `cspm-remed-demo-redeploy` SSM document | Yes |
| `make fix-pr DEP=log4j\|commons-text\|jackson [DRY_RUN=1]` | One-line dependency bump on a `fix/…` branch, then a PR (**y/N**) | Yes, after confirmation |

## Scan timing (observed in this sandbox)
| Event | Observed |
|---|---|
| New S3 / security group resource → first failing misconfiguration | 6–20 min |
| New IAM user → "IAM user has administrative privileges" | ~1 h 50 min |
| New IAM user → "...and is inactive" | ~6 h |
| Security group fixed (rule revoked) → finding passes | ~9 min |
| Security group re-armed (rule re-created) → finding fails again (notification fires) | ~2 min |
| Datadog docs: misconfiguration re-evaluation interval | 15 min to 4 h depending on resource type |
| Container image vulnerabilities | After the Agent scans a newly pulled image (minutes) |
| Host vulnerabilities | After the Agent's host SBOM scan (first one at boot, then periodic) |

The findings API and UI can lag `evaluation_changed_at` by a while. **Notification rules only fire when a finding starts failing**, so a finding that's already failing won't post again until it has passed once. `make break` after a fix is what re-arms the Slack route.

## Demo-day checklist
- **T-24 h or earlier:** run `make break` and confirm the plan. Then:
  - `make status`: everything shows ARMED, and the host runs `DEMO_BASELINE_TAG`.
  - In Datadog, check that the S3 (`hkp-p6b-f7w`, `def-000-ea8`), security group (`tch-c9p-gh4`) and IAM user (`def-000-eui`) findings are failing with `env:demo`.
  - Check that the container image shows Log4Shell, Text4Shell and the jackson CVEs.
- **T-2 h:** run `make status` again. Check that #mdorn-demo-public has the notification posts. Have the Jira project `KAN` board open.
- **During the demo:**
  1. **Detect:** Cloud Security → Misconfigurations and Vulnerabilities, filtered on `env:demo`.
  2. **Prioritize:** severity, the public bucket and admin user, Log4Shell (critical, exploit available).
  3. **Route:** the Slack posts from the `cspm-remed-demo-*` notification rules. Create a Jira issue from the finding panel.
  4. **Remediate:**
     - Misconfigurations: enable Block Public Access on the bucket, and remove the 0.0.0.0/0 rule. Use the console, the finding panel's fix, or (once built) the workflows.
     - Vulnerabilities: in GitHub's web editor, change `<log4j.version>2.14.1</log4j.version>` to `2.26.1` → create a branch and PR → merge (or run `make fix-pr DEP=log4j`).
  5. **Verify:**
     - The security group finding passes in about 10 minutes.
     - The Action builds and redeploys (`make status` shows the new tag).
     - The image findings for log4j close after the Agent scans the new image.
- **After:** run `make reset` and confirm. Merge the revert PR if one was opened, and close the Jira issues it lists.


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

## Full teardown (run each destroy only after reviewing its plan)
Run `scripts/preflight.sh` first, and `export TF_VAR_dd_api_key="$DD_API_KEY" TF_VAR_datadog_app_key_id=$(scripts/dd-app-key-id.sh)`.
1. **Datadog notification rules:** `terraform -chdir=datadog destroy -target=datadog_security_notification_rule.s3_public -target=datadog_security_notification_rule.sg_open_ssh -target=datadog_security_notification_rule.critical_vulns`. Use a targeted destroy, never a full one; see step 6. If you built workflows in the UI, delete them there too.
2. `infra/vuln-host/`: `terraform destroy` removes the EC2 host, ECR repo (`force_delete`, images included), SSM parameter and document, host role and security group.
3. `infra/vulnerable/`: `terraform destroy` removes the bucket (`force_destroy`, placeholder included), the security group and the IAM user.
4. `infra/datadog-iam/`: `terraform destroy` removes the Workflow connection and role, the GitHub OIDC provider and role, and the app key registration. Run it **before** `infra/network/`, because it looks up the demo VPC.
5. `infra/network/`: `terraform destroy`.
6. `datadog/`: use `terraform state rm datadog_integration_aws_account.demo datadog_agentless_scanning_aws_scan_options.demo` rather than destroy, so the pre-existing integration and scan options stay in place. They also have `prevent_destroy`.
7. **Left in place on purpose:**
   - the CloudFormation stacks (`DatadogIntegration*`, `DatadogAgentlessIntegration`)
   - the GitHub repo and its branches
   - Jira issues in `KAN` (use the JQL from `make reset`)
   - the Slack channel
   - the app key's Actions API Access toggle (turn it off in the UI if you like)
8. **Last:** delete the local `terraform.tfstate*` and `.terraform/` folders, but only after every stack above is destroyed.

## Building the remediation workflows (optional, not yet built)
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
