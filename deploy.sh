#!/bin/bash
set -e

# Check for Terraform CLI
if ! command -v terraform >/dev/null 2>&1; then
  echo "Error: Terraform CLI is not installed or not in PATH."
  exit 1
fi

# Check for AWS CLI
if ! command -v aws >/dev/null 2>&1; then
  echo "Error: AWS CLI is not installed or not in PATH."
  exit 1
fi

cd deployment

terraform init
terraform apply -auto-approve

# Get the public IP of the instance
echo "Retrieving public IP of EC2 instance..."
PUBLIC_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=parking-lot-api-instance" \
  --query "Reservations[0].Instances[0].PublicIpAddress" \
  --region us-east-1 \
  --output text)

if [[ -z "$PUBLIC_IP" || "$PUBLIC_IP" == "None" ]]; then
  echo "Failed to retrieve EC2 public IP."
  exit 1
fi

echo "Waiting for application to become responsive at http://${PUBLIC_IP}:8000/ ..."

MAX_RETRIES=30
RETRY_INTERVAL=2
ATTEMPT=1

while ! curl -s --max-time 2 "http://${PUBLIC_IP}:8000/" | grep -q "ok"; do
  if [ "$ATTEMPT" -ge "$MAX_RETRIES" ]; then
    echo "Application did not respond after $((MAX_RETRIES * RETRY_INTERVAL)) seconds. Exiting."
    exit 1
  fi
  sleep "$RETRY_INTERVAL"
  ATTEMPT=$((ATTEMPT + 1))
done

echo ""
echo "Deployment complete."
echo "API available at: http://${PUBLIC_IP}:8000/"
echo "SSH access: ssh -i deployment/parking-lot-key.pem ec2-user@${PUBLIC_IP}"
