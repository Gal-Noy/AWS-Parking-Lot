from fastapi import FastAPI, HTTPException, Query
from ticket_store import store_entry, get_entry_and_remove
from utils import calculate_fee
import uuid

app = FastAPI()

@app.post("/entry")
def entry(plate: str = Query(...), parkingLot: str = Query(...)):
    ticket_id = str(uuid.uuid4())
    store_entry(ticket_id, plate, parkingLot)
    return {"ticketId": ticket_id}

@app.post("/exit")
def exit(ticketId: str = Query(...)):
    entry = get_entry_and_remove(ticketId)
    if not entry:
        raise HTTPException(status_code=404, detail="Ticket not found")

    total_minutes, fee = calculate_fee(entry["timestamp"])
    return {
        "plate": entry["plate"],
        "parkingLot": entry["parkingLot"],
        "totalTimeMinutes": total_minutes,
        "charge": fee
    }

