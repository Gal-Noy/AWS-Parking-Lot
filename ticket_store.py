import boto3
import os
from fastapi import HTTPException
from boto3.dynamodb.conditions import Attr
import datetime

dynamodb = boto3.resource("dynamodb", region_name=os.getenv("AWS_REGION"))
table = dynamodb.Table("ParkingTickets")
print(f'Successfully connected to DynamoDB table: {table.name}')

def store_entry(ticket_id: str, plate: str, parking_lot: str):
    # Prevent duplicate entry for same plate
    response = table.scan(
        FilterExpression=Attr("plate").eq(plate)
    )
    if response.get("Items"):
        raise HTTPException(status_code=409, detail="Car is already in the parking lot")

    table.put_item(Item={
        "ticketId": ticket_id,
        "plate": plate,
        "parkingLot": parking_lot,
        "timestamp": datetime.datetime.now().isoformat()
    })

def get_entry_and_remove(ticket_id: str):
    response = table.get_item(Key={"ticketId": ticket_id})
    item = response.get("Item")
    if not item:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    table.delete_item(Key={"ticketId": ticket_id})
    return item
