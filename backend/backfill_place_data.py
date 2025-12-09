"""
Backfill script to update existing places with missing opening hours and photos.

This script:
1. Finds all places with missing opening_hours or photo_url
2. Fetches fresh data from Google Places API using place_id
3. Updates the database with complete data

Usage:
    python3 backfill_place_data.py
"""

import asyncio
import os
import sys
from sqlalchemy import select
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from database import DATABASE_URL
from models import Place
from google_places_helper import _get_place_details, _format_place_data
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create async engine
engine = create_async_engine(DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def backfill_places():
    """Backfill missing data for all places"""
    
    async with AsyncSessionLocal() as db:
        # Get all places
        result = await db.execute(select(Place))
        places = result.scalars().all()
        
        logger.info(f"📊 Found {len(places)} places to check")
        
        updated_count = 0
        failed_count = 0
        
        for place in places:
            # Check if missing data
            needs_update = False
            
            if not place.opening_hours:
                logger.info(f"⚠️ {place.name} missing opening_hours")
                needs_update = True
            
            if not place.photo_url:
                logger.info(f"⚠️ {place.name} missing photo_url")
                needs_update = True
            
            if not needs_update:
                logger.info(f"✅ {place.name} has complete data")
                continue
            
            # Fetch fresh data from Google
            if not place.google_place_id:
                logger.warning(f"⚠️ {place.name} has no google_place_id, skipping")
                failed_count += 1
                continue
            
            logger.info(f"🔄 Fetching fresh data for {place.name}...")
            
            place_details = _get_place_details(place.google_place_id)
            
            if not place_details:
                logger.error(f"❌ Failed to fetch data for {place.name}")
                failed_count += 1
                continue
            
            # Update opening hours
            if not place.opening_hours:
                opening_hours_data = place_details.get("opening_hours", {})
                if opening_hours_data:
                    weekday_text = opening_hours_data.get("weekday_text", [])
                    if weekday_text:
                        import json
                        place.opening_hours = json.dumps(weekday_text)
                        logger.info(f"  ✅ Added opening_hours")
            
            # Update photo
            if not place.photo_url:
                photos = place_details.get("photos", [])
                if photos:
                    photo_reference = photos[0].get("photo_reference")
                    if photo_reference:
                        GOOGLE_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY")
                        place.photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference={photo_reference}&key={GOOGLE_API_KEY}"
                        logger.info(f"  ✅ Added photo_url")
            
            updated_count += 1
        
        # Commit all changes
        await db.commit()
        
        logger.info(f"\n🎉 Backfill complete!")
        logger.info(f"  ✅ Updated: {updated_count}")
        logger.info(f"  ❌ Failed: {failed_count}")
        logger.info(f"  📊 Total: {len(places)}")


if __name__ == "__main__":
    asyncio.run(backfill_places())
