#!/bin/bash

# Update system packages
yum update -y

# Install dependencies
yum install -y python3 git

# Upgrade pip
python3 -m ensurepip --upgrade

# Clone the repository
git clone https://github.com/Gal-Noy/AWS-Parking-Lot app
cd app

# Install Python dependencies
pip3 install -r requirements.txt

# Run FastAPI with Uvicorn in background
uvicorn main:app --host 0.0.0.0 --port 8000