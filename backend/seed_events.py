"""
Seed script to add sample Hong Kong events
Run with: python3 seed_events.py
"""

import asyncio
from datetime import datetime, timedelta
from database import init_db, get_db
from models import Event

async def seed_events():
    """Add sample events to database"""
    await init_db()
    
    # Get database session
    async for db in get_db():
        # Sample Hong Kong events
        events = [
            Event(
                name="PMQ Night Market",
                description="Creative market with local designers, handmade crafts, and food stalls",
                photo_url="https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
                location="PMQ",
                district="Central",
                start_date=datetime.utcnow(),
                end_date=datetime.utcnow() + timedelta(days=7),
                category="market",
                url="https://pmq.org.hk",
                time_description="Tonight"
            ),
            Event(
                name="Temple Street Night Market",
                description="Famous night market with fortune tellers, street food, and souvenirs",
                photo_url="https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
                location="Temple Street",
                district="Yau Ma Tei",
                start_date=datetime.utcnow(),
                end_date=datetime.utcnow() + timedelta(days=365),
                category="market",
                url="https://www.discoverhongkong.com",
                time_description="Tonight"
            ),
            Event(
                name="Tai Kwun Night Market",
                description="Heritage site with art exhibitions, performances, and dining",
                photo_url="https://images.unsplash.com/photo-1536924940846-227afb31e2a5?w=800",
                location="Tai Kwun",
                district="Central",
                start_date=datetime.utcnow(),
                end_date=datetime.utcnow() + timedelta(days=30),
                category="culture",
                url="https://www.taikwun.hk",
                time_description="Tonight"
            ),
            Event(
                name="Clockenflap Music Festival",
                description="Hong Kong's biggest outdoor music and arts festival",
                photo_url="https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800",
                location="Central Harbourfront",
                district="Central",
                start_date=datetime.utcnow() + timedelta(days=3),
                end_date=datetime.utcnow() + timedelta(days=5),
                category="music",
                url="https://www.clockenflap.com",
                time_description="This Weekend"
            ),
            Event(
                name="Hong Kong Wine & Dine Festival",
                description="Annual food and wine festival at the harbourfront",
                photo_url="https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=800",
                location="Central Harbourfront",
                district="Central",
                start_date=datetime.utcnow() + timedelta(days=14),
                end_date=datetime.utcnow() + timedelta(days=18),
                category="food",
                url="https://www.discoverhongkong.com",
                time_description="Next Week"
            )
        ]
        
        # Add to database
        for event in events:
            db.add(event)
        
        await db.commit()
        print(f"✅ Seeded {len(events)} events")
        break

if __name__ == "__main__":
    asyncio.run(seed_events())
