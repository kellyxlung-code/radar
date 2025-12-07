"""
Add sample Hong Kong events to database
"""
import asyncio
from datetime import datetime, timedelta
from database import AsyncSessionLocal
from models import Event

async def add_sample_events():
    """Add sample events for testing"""
    
    events_data = [
        {
            "name": "PMQ Night Market",
            "description": "Creative market with local designers, handmade crafts, and food stalls",
            "photo_url": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
            "location": "PMQ",
            "district": "Central",
            "lat": 22.2842,
            "lng": 114.1533,
            "start_date": datetime.now(),
            "end_date": datetime.now() + timedelta(days=7),
            "category": "market",
            "url": "https://pmq.org.hk"
        },
        {
            "name": "Temple Street Night Market",
            "description": "Famous night market with fortune tellers, street food, and souvenirs",
            "photo_url": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
            "location": "Temple Street",
            "district": "Yau Ma Tei",
            "lat": 22.3092,
            "lng": 114.1713,
            "start_date": datetime.now(),
            "end_date": datetime.now() + timedelta(days=365),
            "category": "market",
            "url": "https://www.discoverhongkong.com"
        },
        {
            "name": "Tai Kwun Night Market",
            "description": "Heritage site with art exhibitions, performances, and dining",
            "photo_url": "https://images.unsplash.com/photo-1536924940846-227afb31e2a5?w=800",
            "location": "Tai Kwun",
            "district": "Central",
            "lat": 22.2819,
            "lng": 114.1548,
            "start_date": datetime.now(),
            "end_date": datetime.now() + timedelta(days=30),
            "category": "culture",
            "url": "https://www.taikwun.hk"
        },
        {
            "name": "Clockenflap 2024",
            "description": "Hong Kong's biggest music and arts festival",
            "photo_url": "https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800",
            "location": "Central Harbourfront",
            "district": "Central",
            "lat": 22.2855,
            "lng": 114.1577,
            "start_date": datetime(2024, 11, 22),
            "end_date": datetime(2024, 11, 24),
            "category": "music",
            "url": "https://clockenflap.com"
        },
        {
            "name": "Hong Kong Wine & Dine Festival",
            "description": "Annual food and wine festival at the harbourfront",
            "photo_url": "https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=800",
            "location": "Central Harbourfront",
            "district": "Central",
            "lat": 22.2855,
            "lng": 114.1577,
            "start_date": datetime.now() + timedelta(days=14),
            "end_date": datetime.now() + timedelta(days=18),
            "category": "food",
            "url": "https://www.discoverhongkong.com"
        }
    ]
    
    async with AsyncSessionLocal() as db:
        for event_data in events_data:
            event = Event(**event_data)
            db.add(event)
        
        await db.commit()
        print(f"✅ Added {len(events_data)} sample events!")

if __name__ == "__main__":
    asyncio.run(add_sample_events())
