"""
Google Places Autocomplete for manual search
"""

import os
import logging
import httpx
from typing import List, Optional, Dict

logger = logging.getLogger(__name__)

GOOGLE_PLACES_API_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "").strip()


async def autocomplete_search(query: str, location: str = "22.3193,114.1694") -> List[Dict]:
    """
    Search for places using Google Places Autocomplete API.
    
    Args:
        query: Search query (e.g., "Bar Leone")
        location: Lat,lng for bias (default: Hong Kong)
    
    Returns:
        List of place predictions with name, address, place_id
    """
    
    if not GOOGLE_PLACES_API_KEY:
        logger.warning("⚠️ Google Places API key not configured")
        return []
    
    url = "https://maps.googleapis.com/maps/api/place/autocomplete/json"
    
    params = {
        "input": query,
        "key": GOOGLE_PLACES_API_KEY,
        "location": location,
        "radius": 50000,  # 50km radius
        "types": "establishment",  # Only businesses/places
        "components": "country:hk"  # Restrict to Hong Kong
    }
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
        
        if data.get("status") != "OK":
            logger.warning(f"⚠️ Autocomplete API status: {data.get('status')}")
            return []
        
        predictions = data.get("predictions", [])
        
        # Format results with place details (including photos)
        results = []
        for pred in predictions[:10]:  # Limit to 10 results
            place_id = pred.get("place_id")
            
            # Get full place details to include photo
            place_details = await get_place_details(place_id)
            
            if place_details:
                results.append({
                    "place_id": place_details.get("place_id"),
                    "name": place_details.get("name", ""),
                    "address": place_details.get("address", ""),
                    "lat": place_details.get("lat", 0.0),
                    "lng": place_details.get("lng", 0.0),
                    "photoUrl": place_details.get("photo_url"),  # Backend returns photo_url (snake_case)
                    "rating": place_details.get("rating"),
                })
            else:
                # Fallback if details fetch fails
                results.append({
                    "place_id": place_id,
                    "name": pred.get("structured_formatting", {}).get("main_text", ""),
                    "address": pred.get("description", ""),
                    "lat": 0.0,
                    "lng": 0.0,
                    "photoUrl": None,
                    "rating": None,
                })
        
        logger.info(f"✅ Found {len(results)} autocomplete results for '{query}'")
        return results
    
    except Exception as e:
        logger.error(f"❌ Autocomplete search error: {e}")
        return []


async def get_place_details(place_id: str) -> Optional[Dict]:
    """
    Get full place details from Google Places using place_id.
    Returns same format as enrich_place_data() for consistency.
    """
    
    if not GOOGLE_PLACES_API_KEY:
        logger.warning("⚠️ Google Places API key not configured")
        return None
    
    url = "https://maps.googleapis.com/maps/api/place/details/json"
    
    params = {
        "place_id": place_id,
        "key": GOOGLE_PLACES_API_KEY,
        "fields": "name,formatted_address,geometry,photos,rating,price_level,opening_hours,formatted_phone_number,website,types"
    }
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(url, params=params)
            response.raise_for_status()
            data = response.json()
        
        if data.get("status") != "OK":
            logger.warning(f"⚠️ Place Details API status: {data.get('status')}")
            return None
        
        result = data.get("result", {})
        
        # Extract photo URL
        photo_url = None
        if result.get("photos"):
            photo_reference = result["photos"][0].get("photo_reference")
            if photo_reference:
                photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference={photo_reference}&key={GOOGLE_PLACES_API_KEY}"
        
        # Extract location
        location = result.get("geometry", {}).get("location", {})
        
        place_data = {
            "place_id": place_id,
            "name": result.get("name"),
            "address": result.get("formatted_address"),
            "lat": location.get("lat"),
            "lng": location.get("lng"),
            "photo_url": photo_url,
            "rating": result.get("rating"),
            "price_level": result.get("price_level"),
            "phone": result.get("formatted_phone_number"),
            "website": result.get("website"),
            "types": result.get("types", []),
            "opening_hours": result.get("opening_hours"),
        }
        
        logger.info(f"✅ Got place details for: {place_data.get('name')}")
        return place_data
    
    except Exception as e:
        logger.error(f"❌ Place details error: {e}")
        return None
