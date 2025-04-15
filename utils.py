import datetime

def calculate_fee(entry_time: str):
    entry_time_dt = datetime.datetime.fromisoformat(entry_time)
    now = datetime.datetime.now()
    duration_minutes = int((now - entry_time_dt).total_seconds() / 60)
    quarter_hours = (duration_minutes + 14) // 15  # round up to nearest 15 min
    fee = quarter_hours * (10 / 4)  # $10/hour → $2.5/15min
    return duration_minutes, fee
