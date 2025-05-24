# Parking Lot Management System (FastAPI + AWS)

This is a simple cloud-based parking lot management system built using FastAPI. It runs on an EC2 instance and uses AWS DynamoDB for data storage.

## Technologies Used

- Python 3
- FastAPI
- AWS EC2
- AWS DynamoDB
- Uvicorn
- Boto3

## Endpoints

### `GET /`
Health check endpoint  
**Example**:  
```bash
curl http://3.92.223.19:8000/
```

### `POST /entry`
Registers a new car entry into the parking lot  
**Required query parameters**: `plate`, `parkingLot`  
**Example**:  
```bash
curl -X POST "http://3.92.223.19:8000/entry?plate=123-456-789&parkingLot=385"
```

**Response**:  
```json
{
  "ticketId": "<uuid>"
}
```

### `POST /exit`
Closes a parking ticket and returns the total time and fee  
**Required query parameter**: `ticketId`  
**Example**:  
```bash
curl -X POST "http://3.92.223.19:8000/exit?ticketId=<ticket-id>"
```

**Response**:  
```json
{
  "plate": "123-456-789",
  "parkingLot": "385",
  "totalTimeMinutes": 42,
  "charge": 7.0
}
```

## Deployment Process

1. **EC2 Instance Setup**  
   Launched an EC2 instance running Amazon Linux 2. Inbound traffic on port **8000** was enabled in the security group to allow external access to the FastAPI application.

2. **IAM Role Configuration**  
   Attached an IAM role to the EC2 instance with permissions to access **AWS DynamoDB**, used for storing parking ticket data.

3. **DynamoDB Table Creation**  
   Created a DynamoDB table named `ParkingTickets` with the following configuration:
   - Primary key: `ticketId` (String)

4. **Application Deployment**  
   Used the `user_data.sh` script to automate the setup of the application environment. The script performs the following actions:
   - Updates system packages
   - Installs Python and Git
   - Clones the project repository
   - Installs required Python dependencies
   - Starts the FastAPI application using `uvicorn` on port 8000

   Deployment script:
   ```bash
   ./user_data.sh
   ```

5. **Accessing the Application**  
   After deployment, the application was accessible at:
   ```
   http://3.92.223.19:8000
   ```

   API endpoints were tested using:
   - `curl` in **Git Bash**
   - **Postman**

## Authors

Gal Noy – Cloud Computing Assignment
