#!/bin/bash
set -euo pipefail

REGION="us-east-1"
AMI_ID="ami-0953476d60561c955"
INSTANCE_TYPE="t2.micro"
KEY_NAME="parking-lot-key"
SECURITY_GROUP_NAME="parking-lot-sg"
TABLE_NAME="ParkingTickets"
INSTANCE_NAME="parking-lot-api-instance"
IAM_ROLE_NAME="parking-lot-api-role"
INSTANCE_PROFILE_NAME="parking-lot-api-profile"
USER_DATA_FILE="user_data.sh"
ASSUME_ROLE_POLICY_FILE="assume-role-policy.json"

cd "$(dirname "$0")"

command -v aws >/dev/null || { echo "AWS CLI is not installed."; exit 1; }

echo "Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=ticketId,AttributeType=S \
  --key-schema AttributeName=ticketId,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" > /dev/null 2>&1
echo "DynamoDB table '$TABLE_NAME' created."

echo "Creating IAM role..."
aws iam create-role \
  --role-name "$IAM_ROLE_NAME" \
  --assume-role-policy-document file://"$ASSUME_ROLE_POLICY_FILE" \
  --region "$REGION" > /dev/null 2>&1
echo "IAM role '$IAM_ROLE_NAME' created."

echo "Attaching DynamoDB policy to IAM role..."
aws iam attach-role-policy \
  --role-name "$IAM_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess \
  --region "$REGION" > /dev/null 2>&1
echo "Policy attached to IAM role."

echo "Creating instance profile..."
aws iam create-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --region "$REGION" > /dev/null 2>&1
echo "Instance profile '$INSTANCE_PROFILE_NAME' created."

echo "Attaching IAM role to instance profile..."
aws iam add-role-to-instance-profile \
  --instance-profile-name "$INSTANCE_PROFILE_NAME" \
  --role-name "$IAM_ROLE_NAME" \
  --region "$REGION" > /dev/null 2>&1
echo "IAM role attached to instance profile."

echo "Waiting for IAM instance profile propagation..."
sleep 10

echo "Creating security group..."
SECURITY_GROUP_ID=$(aws ec2 create-security-group \
  --group-name "$SECURITY_GROUP_NAME" \
  --description "Allow HTTP and SSH" \
  --region "$REGION" \
  --query 'GroupId' --output text 2>/dev/null)
echo "Security group '$SECURITY_GROUP_NAME' created."

echo "Authorizing ports on security group..."
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$REGION" > /dev/null 2>&1
aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" \
  --protocol tcp --port 8000 --cidr 0.0.0.0/0 --region "$REGION" > /dev/null 2>&1
echo "Ports authorized."

echo "Creating EC2 key pair..."
aws ec2 delete-key-pair --key-name "$KEY_NAME" --region "$REGION" > /dev/null 2>&1 || true
rm -f "${KEY_NAME}.pem"
aws ec2 create-key-pair --key-name "$KEY_NAME" \
  --query 'KeyMaterial' --output text \
  --region "$REGION" > "${KEY_NAME}.pem" 2>/dev/null
chmod 400 "${KEY_NAME}.pem"
echo "Key pair '${KEY_NAME}.pem' created."

echo "Verifying user data script exists..."
[ -f "$USER_DATA_FILE" ] || { echo "Missing file: $USER_DATA_FILE"; exit 1; }

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --count 1 \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" \
  --user-data "file://$USER_DATA_FILE" \
  --region "$REGION" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --query 'Instances[0].InstanceId' --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "Failed to launch EC2 instance. Exiting."
  exit 1
fi

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION" > /dev/null 2>&1

PUBLIC_IP=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

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
echo "SSH access: ssh -i ${KEY_NAME}.pem ec2-user@${PUBLIC_IP}"
