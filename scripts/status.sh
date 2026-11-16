#!/usr/bin/env bash
# Read-only snapshot of the demo environment. Changes nothing.
set -uo pipefail

REGION=us-east-2
EXPECTED_ACCOUNT=897722680419
PREFIX=cspm-remed-demo
INSTANCE_NAME=$PREFIX-vuln-host
REPO=$PREFIX-app
SG_NAME=$PREFIX-open-ssh
IAM_USER=$PREFIX-overprivileged
GH_REPO=mdorn/datadog-cloud-security-demo
export AWS_PROFILE="${AWS_PROFILE:-default}" AWS_REGION="$REGION"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

hr() { printf '\n== %s\n' "$1"; }
armed() { if [[ "$1" == yes ]]; then echo "ARMED (misconfigured)"; else echo "fixed / not armed"; fi; }

hr "AWS account"
acct=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "?")
echo "account: $acct $([[ "$acct" == "$EXPECTED_ACCOUNT" ]] && echo "(OK)" || echo "(UNEXPECTED: expected $EXPECTED_ACCOUNT)")"
[[ "$acct" == "$EXPECTED_ACCOUNT" ]] || exit 1

hr "S3 bucket"
bucket=$(terraform -chdir="$ROOT/infra/vulnerable" output -raw bucket_name 2>/dev/null || echo "")
if [[ -n "$bucket" ]]; then
  bpa=$(aws s3api get-public-access-block --bucket "$bucket" \
    --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,IgnorePublicAcls,BlockPublicPolicy,RestrictPublicBuckets]' \
    --output text 2>/dev/null || echo "none none none none")
  code=$(curl -s -o /dev/null -w '%{http_code}' "https://$bucket.s3.$REGION.amazonaws.com/placeholder.txt")
  [[ "$bpa" == *True* ]] && a=no || a=yes
  echo "$bucket  BPA=[$bpa]  anonymous GET placeholder.txt=$code  -> $(armed $a)"
else
  echo "bucket not found in infra/vulnerable outputs"
fi

hr "Security group $SG_NAME"
sg=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SG_NAME" \
  --query 'SecurityGroups[0].[GroupId,length(IpPermissions[?FromPort==`22` && IpRanges[?CidrIp==`0.0.0.0/0`]])]' --output text 2>/dev/null)
read -r sgid open22 <<<"$sg"
[[ "${open22:-0}" -gt 0 ]] && a=yes || a=no
echo "${sgid:-?}  tcp/22 from 0.0.0.0/0: $([[ $a == yes ]] && echo present || echo absent)  -> $(armed $a)"

hr "IAM user $IAM_USER"
pol=$(aws iam list-user-policies --user-name "$IAM_USER" --query 'PolicyNames' --output text 2>/dev/null || echo "")
keys=$(aws iam list-access-keys --user-name "$IAM_USER" --query 'length(AccessKeyMetadata)' --output text 2>/dev/null || echo "?")
[[ "$pol" == *broad-access* ]] && a=yes || a=no
echo "inline policies: ${pol:-none}  access keys: $keys  -> $(armed $a)"

hr "Host and running image"
inst=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=pending,running,stopping,stopped" \
  --query 'Reservations[0].Instances[0].[InstanceId,State.Name,ImageId,InstanceType]' --output text 2>/dev/null)
read -r iid istate iami itype <<<"$inst"
echo "instance: ${iid:-none} ${istate:-} ${iami:-} ${itype:-}"
if [[ "${istate:-}" == running ]]; then
  ping=$(aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$iid" --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null)
  echo "ssm: $ping"
  cid=$(aws ssm send-command --instance-ids "$iid" --document-name AWS-RunShellScript \
    --parameters 'commands=["docker inspect demo-app 2>/dev/null | python3 -c \"import json,sys; c=json.load(sys.stdin)[0]; print(c[\\\"Config\\\"][\\\"Image\\\"], c[\\\"Image\\\"], c[\\\"State\\\"][\\\"Status\\\"])\" || echo no container","cat /etc/cspm-remed-demo/image-tag 2>/dev/null || echo no-tag-file"]' \
    --query Command.CommandId --output text 2>/dev/null)
  for _ in 1 2 3 4 5 6; do
    sleep 2
    out=$(aws ssm get-command-invocation --command-id "$cid" --instance-id "$iid" --query '[Status,StandardOutputContent]' --output text 2>/dev/null) || continue
    [[ "$out" == Success* ]] && break
  done
  echo "running: $(echo "$out" | sed '1s/^Success[[:space:]]*//' | tr '\n' ' ')"
fi
baseline=$(cat "$ROOT/DEMO_BASELINE_TAG" 2>/dev/null || echo "?")
echo "vulnerable baseline tag: $baseline"

hr "ECR $REPO (newest 3)"
aws ecr describe-images --repository-name "$REPO" \
  --query 'reverse(sort_by(imageDetails[?imageTags!=null],&imagePushedAt))[:3].[imageTags[0],imagePushedAt,imageDigest]' --output text 2>/dev/null

hr "GitHub Actions (latest run)"
gh run list --repo "$GH_REPO" --limit 1 --json displayTitle,status,conclusion,headSha,createdAt \
  --jq '.[] | "\(.createdAt) \(.status)/\(.conclusion) \(.headSha[0:12]) \(.displayTitle)"' 2>/dev/null || echo "gh unavailable"
