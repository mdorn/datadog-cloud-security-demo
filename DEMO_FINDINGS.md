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

Account findings on non-demo resources (`mdorn-dd`, `launch-wizard-5`, IAM users `mdorn`, `dd-svc-acct`, `malicious-iam-user`, default security groups) also match these rules. **Filter on `env:demo`** to see only the demo findings.

## Routing (Phase 4)
No OOTB rule rates these misconfigurations as critical. Notifications route `env:demo` misconfigurations of **medium severity and above**, plus critical vulnerabilities.
