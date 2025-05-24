#!/bin/bash
set -euo pipefail

REGION="us-east-1"
INSTANCE_TAG="parking-lot-api-instance"
KEY_FILE="deployment/parking-lot-key.pem"

# Check for required tools
for cmd in terraform aws curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: '$cmd' is not installed or not in PATH."
    exit 1
  fi
done

cd deployment

echo "Deploying infrastructure with Terraform..."
terraform init
terraform apply -auto-approve

echo "Looking up EC2 instance..."
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=$INSTANCE_TAG" \
            "Name=instance-state-name,Values=pending,running" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --region "$REGION" \
  --output text)

if [[ -z "$INSTANCE_ID" || "$INSTANCE_ID" == "None" ]]; then
  echo "Failed to find EC2 instance with tag '$INSTANCE_TAG' in pending/running state."
  exit 1
fi

echo "Waiting for EC2 instance ($INSTANCE_ID) to enter 'running' state..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "Fetching public IP..."
PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --output text)

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  echo "Failed to retrieve public IP address for instance."
  exit 1
fi

echo "Waiting for application to become responsive at http://${PUBLIC_IP}:8000/ ..."
MAX_RETRIES=30
RETRY_INTERVAL=2
ATTEMPT=1

while ! curl -s --max-time 2 "http://${PUBLIC_IP}:8000/" | grep -q "ok"; do
  if [[ "$ATTEMPT" -ge "$MAX_RETRIES" ]]; then
    echo "Application did not respond after $((MAX_RETRIES * RETRY_INTERVAL)) seconds."
    exit 1
  fi
  sleep "$RETRY_INTERVAL"
  ATTEMPT=$((ATTEMPT + 1))
done

echo ""
echo "Deployment complete."
echo "API available at: http://${PUBLIC_IP}:8000/"
echo "SSH access:"
echo "ssh -i $KEY_FILE ec2-user@${PUBLIC_IP}"
