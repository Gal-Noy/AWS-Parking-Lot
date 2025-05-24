## Parking Lot Management System (FastAPI + AWS)

A serverless-ready parking lot system using FastAPI on an AWS EC2 instance with DynamoDB. Infrastructure is deployed via `Terraform` and managed with a simple `deploy.sh` script.

## Stack

- FastAPI + Uvicorn
- Python 3
- AWS EC2 & DynamoDB
- Terraform
- Boto3

## API Endpoints

### `GET /`
Health check  
```bash
curl http://<public-ip>:8000/
```

### `POST /entry`
Register car entry  
```bash
curl -X POST "http://<public-ip>:8000/entry?plate=123-456-789&parkingLot=385"
```

### `POST /exit`
Close ticket  
```bash
curl -X POST "http://<public-ip>:8000/exit?ticketId=<ticket-id>"
```

## Deployment

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- `curl`

Configure AWS credentials:
```bash
aws configure
```

### Steps

Clone the repo:

```bash
git clone https://github.com/Gal-Noy/AWS-Parking-Lot
cd AWS-Parking-Lot
```

Make the deploy script executable and run it:

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will deploy the infra, wait for the app to respond, and print access info.

## Architecture

- EC2 instance with IAM role
- DynamoDB table (`ticketId` as primary key)
- SSH + HTTP allowed via Security Group
- TLS key pair saved to `deployment/parking-lot-key.pem`
- App auto-starts with `user_data.sh`

## Access

API:
```bash
curl http://<public-ip>:8000/
```

SSH:
```bash
ssh -i deployment/parking-lot-key.pem ec2-user@<public-ip>
```

## Author

Gal Noy – Cloud Computing Assignment, Reichman University
