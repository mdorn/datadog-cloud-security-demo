#!/usr/bin/env bash
# Deploy an image tag of cspm-remed-demo-app to the demo host via the
# cspm-remed-demo-redeploy SSM document. Usage: deploy-image.sh [TAG]
# Without TAG, deploys the most recently pushed image.
set -euo pipefail

REGION=us-east-2
REPO=cspm-remed-demo-app
INSTANCE_NAME=cspm-remed-demo-vuln-host
DOCUMENT=cspm-remed-demo-redeploy
export AWS_PROFILE="${AWS_PROFILE:-default}"

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  TAG=$(aws ecr describe-images --region "$REGION" --repository-name "$REPO" \
    --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)
fi
if [[ ! "$TAG" =~ ^[0-9a-f]{12}$ ]]; then
  echo "deploy-image: invalid or missing tag '$TAG'" >&2
  exit 1
fi

INSTANCE_ID=$(aws ec2 describe-instances --region "$REGION" \
  --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' --output text)
if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "deploy-image: no running instance named $INSTANCE_NAME" >&2
  exit 1
fi

echo "deploy-image: $REPO:$TAG -> $INSTANCE_ID"
CMD_ID=$(aws ssm send-command --region "$REGION" --instance-ids "$INSTANCE_ID" \
  --document-name "$DOCUMENT" --parameters "ImageTag=$TAG" \
  --comment "make deploy-image $TAG" --query 'Command.CommandId' --output text)

status=Pending
for _ in $(seq 1 60); do
  status=$(aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" \
    --instance-id "$INSTANCE_ID" --query Status --output text 2>/dev/null || echo Pending)
  [[ "$status" =~ ^(Success|Failed|Cancelled|TimedOut)$ ]] && break
  sleep 5
done

aws ssm get-command-invocation --region "$REGION" --command-id "$CMD_ID" \
  --instance-id "$INSTANCE_ID" --query '[Status,StandardOutputContent,StandardErrorContent]' --output text
[[ "$status" == "Success" ]]
