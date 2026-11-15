# Demo findings

The intentional misconfigurations in this repo and the Datadog Cloud Security findings they should produce.
They're tracked here rather than in code comments, which would show up in IaC scan results.

Rule names and IDs were verified against the sandbox org's OOTB rules through the Datadog API (2026-11-15).
Findings aren't instant. Resource collection and evaluation can take several hours after a resource is created (see `RUNBOOK.md`).

## Misconfigurations (`infra/vulnerable/`)

| Resource | Misconfiguration | Expected OOTB rule (id) | Severity | Remediation in demo | Re-armed by |
|---|---|---|---|---|---|
| S3 `cspm-remed-demo-public-assets-<suffix>` | Bucket-level Block Public Access off (all four settings `false`) | S3 buckets should have 'Block Public Access' enabled (`hkp-p6b-f7w`) | medium | Workflow `cspm-remed-demo-s3-block-public-access` (enable BPA) | `make break` / `make reset` |
| same | Bucket policy allows `Principal: *` `s3:GetObject` on `placeholder.txt` only | S3 bucket contents should only be accessible by authorized principals (`w95-9o2-mw0`) | high | Same workflow: `RestrictPublicBuckets` makes the policy ineffective | same |
| same | same | S3 bucket policies should not allow wildcard principals (`def-000-ea8`) | high | Same workflow (should pass once BPA is on; verify on first run) | same |
| SG `cspm-remed-demo-open-ssh` | Ingress tcp/22 from `0.0.0.0/0`, attached to nothing | Security groups should restrict traffic to trusted IPv4 addresses (`tch-c9p-gh4`) | medium | Security group workflow (revoke the 0.0.0.0/0 rule) | same |
| IAM user `cspm-remed-demo-overprivileged` | Inline policy `cspm-remed-demo-broad-access` allows `*` on `*` | AWS IAM user has administrative privileges (`def-000-eui`) | high | None (detect/prioritize only) | n/a (not changed by the demo) |
| same | same, and the user is never used | AWS IAM user has administrative privileges and is inactive (`def-000-rf2`) | high | None | n/a |

Note: `def-000-igl` ("Security Group should restrict SSH access from the internet") is an **Azure** NSG rule despite its name. The AWS SSH rule is `tch-c9p-gh4`.

## Vulnerabilities (`infra/vuln-host/`, `app/`)

The Datadog Agent on `cspm-remed-demo-vuln-host` collects these through SBOM (host and container image, `os` + `languages` analyzers). Agentless Scanning skips the host because it runs the Agent.

| Where | Component | Expected | Fix in demo |
|---|---|---|---|
| Container image `cspm-remed-demo-app` | `log4j-core` / `log4j-api` 2.14.1 (`app/pom.xml`, `log4j.version`) | Log4Shell CVE-2021-44228 (critical) and follow-on log4j CVEs | One-line bump of `log4j.version`, merge, Action rebuilds and redeploys |
| same | `commons-text` 1.9 (`commons-text.version`) | Text4Shell CVE-2022-42889 (critical) | One-line bump |
| same | `jackson-databind` 2.9.10.1 (`jackson-databind.version`) | Multiple deserialization CVEs (high/critical) | One-line bump |
| same | Base image `openjdk:8u212-jre-slim-stretch` (Debian 9, end of life) | Many OS package CVEs | Not part of the fix PR |
| Host | Ubuntu 20.04 AMI `ami-00149760ce42c967b` (2023-01-12), automatic updates off | OS package CVEs | Not remediated (the host stays vulnerable) |

The container runs with `--network none --read-only --cap-drop ALL`, so Log4Shell's outbound JNDI lookup has no network path.

## Blast radius
- **Bucket:** contains only `placeholder.txt` ("Contains no data"). Anonymous read is allowed on that one key. There's no listing and no writes, and ACLs are disabled (BucketOwnerEnforced).
- **Security group:** attached to nothing, so nothing is reachable through it.
- **IAM user:** has no access keys, console password or MFA, so there's no way to authenticate as it.

## Incidental / pre-existing findings (not demo targets)
| Rule (id) | Severity | Why |
|---|---|---|
| IAM role cross-account trust should only reference organization accounts (on `cspm-remed-demo-workflow-automation`) | medium | **Expected and accepted.** The role must trust Datadog's AWS account (`464622532012`) with an external ID for Workflow Automation to work. It's tagged `env:demo`, so Phase 4 routing must exclude this rule or mute the finding (ACCEPTED_RISK). |
| S3 Block Public Access feature should be enabled at the account level (`def-000-skz`) | medium | Already failing on `aws_iam_account:897722680419`. Account-level BPA isn't configured and is deliberately left unchanged. |
| VPC flow logs not enabled (demo VPC) | low/medium | Flow logs aren't enabled on `cspm-remed-demo-vpc`, to keep things minimal. |
| S3 versioning / MFA delete / object-level logging / lifecycle (demo bucket) | low | Defaults left unset |
| VPC flow logging should be enabled in all VPCs (demo VPC) | medium | Observed. Flow logs are deliberately off. |
| VPCs should have interface endpoints for SSM / SSM Contacts / SSM Incident Manager / ECR API / ECR Docker Registry; EC2 should use VPC endpoints; VPCs should have endpoints for S3 and DynamoDB (demo VPC) | medium/low | Observed. The host uses its public IP for outbound access instead of endpoints, to save cost. |
| Instance roles should be used for AWS resource access from instances (`cspm-remed-demo-vuln-host`) | medium | Observed. The instance does have an instance profile, so recheck later in case this was evaluated before the profile was attached. |
| IAM user rules: access keys after setup / one active key / unused credentials / policies at group level (`cspm-remed-demo-overprivileged`) | medium/low | Observed. A side effect of the demo IAM user. |

Account findings on non-demo resources (`mdorn-dd`, `launch-wizard-5`, IAM users `mdorn`, `dd-svc-acct`, `malicious-iam-user`, default security groups) also match these rules. **Filter on `env:demo`** to see only the demo findings.

## Routing (Phase 4)
No OOTB rule rates these misconfigurations as critical. The plan was to route `env:demo` misconfigurations of medium severity and above, plus critical vulnerabilities.
**Observed:** about 10 incidental medium findings are also tagged `env:demo` (VPC endpoints, flow logs, and so on). Medium+ routing would post those to Slack too, so revisit this in Phase 4. The likely fix is to filter the notification rule to the demo rule IDs listed above.
