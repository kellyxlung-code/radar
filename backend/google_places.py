"""
Radar Backend - Google Places API Integration
Fetch canonical venue data for place enrichment
"""

import os
import logging
from typing import Optional, Dict, List
import httpx

logger = logging.getLogger(__name__)

GOOGLE_PLACES_KEY = os.getenv("GOOGLE_PLACES_KEY", "").strip()

# API endpoints
PLACES_TEXT_SEARCH_URL = "https://maps.googleapis.com/maps/api/place/textsearch/json"
PLACES_DETAILS_URL = "https://maps.googleapis.com/maps/api/place/details/json"
PLACES_PHOTO_URL = "https://maps.googleapis.com/maps/api/place/photo"


async def search_place(name: str, district: str = None, region: str = "Hong Kong") -> Optional[Dict]:
    """
    Search for a place using Google Places Text Search
    Returns the best matching place with basic info
    """
    if not GOOGLE_PLACES_KEY:
        logger.warning("⚠️ GOOGLE_PLACES_KEY not set. Place enrichment disabled.")
        return None
    
    # Build search query
    query = name
    if district:
        query += f", {district}"
    query += f", {region}"
    
    logger.info(f"🔍 Searching Google Places: {query}")
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                PLACES_TEXT_SEARCH_URL,
                params={
                    "query": query,
                    "key": GOOGLE_PLACES_KEY,
                    "region": "hk",  # Bias to Hong Kong
                }
            )
            response.raise_for_status()
            data = response.json()
        
        if data.get("status") != "OK":
            logger.warning(f"⚠️ Google Places API error: {data.get('status')}")
            return None
        
        results = data.get("results", [])
        if not results:
            logger.warning(f"⚠️ No results found for: {query}")
            return None
        
        # Return first (best) result
        place = results[0]
        
        return {
            "place_id": place.get("place_id"),
            "name": place.get("name"),
            "address": place.get("formatted_address"),
            "lat": place.get("geometry", {}).get("location", {}).get("lat"),
            "lng": place.get("geometry", {}).get("location", {}).get("lng"),
            "rating": place.get("rating"),
            "photo_reference": place.get("photos", [{}])[0].get("photo_reference") if place.get("photos") else None,
        }
    
    except Exception as e:
        logger.error(f"❌ Error searching Google Places: {e}")
        return None


async def get_place_details(place_id: str) -> Optional[Dict]:
    """
    Get detailed information about a place
    Returns full place data including hours, phone, website
    """
    if not GOOGLE_PLACES_KEY:
        return None
    
    logger.info(f"📍 Fetching place details: {place_id}")
    
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                PLACES_DETAILS_URL,
                params={
                    "place_id": place_id,
                    "fields": "name,formatted_address,geometry,rating,price_level,opening_hours,formatted_phone_number,website,photos,types",
                    "key": GOOGLE_PLACES_KEY,
                }
            )
            response.raise_for_status()
            data = response.json()
        
        if data.get("status") != "OK":
            logger.warning(f"⚠️ Google Places Details API error: {data.get('status')}")
            return None
        
        result = data.get("result", {})
        
        # Extract opening hours
        opening_hours = None
        if result.get("opening_hours"):
            opening_hours = {
                "open_now": result["opening_hours"].get("open_now"),
                "weekday_text": result["opening_hours"].get("weekday_text", []),
            }
        
        # Extract first photo reference
        photo_reference = None
        if result.get("photos"):
            photo_reference = result["photos"][0].get("photo_reference")
        
        return {
            "place_id": place_id,
            "name": result.get("name"),
            "address": result.get("formatted_address"),
            "lat": result.get("geometry", {}).get("location", {}).get("lat"),
            "lng": result.get("geometry", {}).get("location", {}).get("lng"),
            "rating": result.get("rating"),
            "price_level": result.get("price_level"),
            "phone": result.get("formatted_phone_number"),
            "website": result.get("website"),
            "opening_hours": opening_hours,
            "photo_reference": photo_reference,
            "types": result.get("types", []),
        }
    
    except Exception as e:
        logger.error(f"❌ Error fetching place details: {e}")
        return None


def get_photo_url(photo_reference: str, max_width: int = 800) -> str:
    """
    Generate Google Places photo URL
    """
    if not GOOGLE_PLACES_KEY or not photo_reference:
        return None
    
    return f"{PLACES_PHOTO_URL}?maxwidth={max_width}&photo_reference={photo_reference}&key={GOOGLE_PLACES_KEY}"


async def enrich_place_data(name: str, district: str = None) -> Optional[Dict]:
    """
    Complete flow: Search + Get Details + Generate Photo URL
    Returns fully enriched place data ready for database
    """
    # Step 1: Search for place
    search_result = await search_place(name, district)
    if not search_result:
        logger.warning(f"⚠️ Could not find place: {name}")
        return None
    
    place_id = search_result.get("place_id")
    if not place_id:
        return search_result  # Return basic data
    
    # Step 2: Get detailed info
    details = await get_place_details(place_id)
    if not details:
        return search_result  # Fallback to search result
    
    # Step 3: Generate photo URL
    photo_reference = details.get("photo_reference")
    if photo_reference:
        details["photo_url"] = get_photo_url(photo_reference)
    
    logger.info(f"✅ Enriched place: {details.get('name')}")
    
    return details


def extract_district_from_address(address: str) -> Optional[str]:
    """
    Extract Hong Kong district from address
    """
    hk_districts = [
        "Central", "Admiralty", "Wan Chai", "Causeway Bay",
        "Tsim Sha Tsui", "TST", "Mong Kok", "Jordan", "Yau Ma Tei",
        "Sham Shui Po", "Sai Ying Pun", "Sheung Wan", "Kennedy Town",
        "Quarry Bay", "Tai Koo", "North Point", "Fortress Hill",
        "Tin Hau", "Tai Hang", "Happy Valley", "Mid-Levels",
        "Stanley", "Repulse Bay", "Aberdeen", "Wong Chuk Hang",
        "Kowloon Tong", "Hung Hom", "To Kwa Wan", "Kowloon City",
        "Kwun Tong", "Ngau Tau Kok", "Lam Tin", "Yau Tong",
        "Sha Tin", "Tai Po", "Fanling", "Sheung Shui",
        "Tuen Mun", "Yuen Long", "Tsuen Wan", "Kwai Chung",
        "Tsing Yi", "Tung Chung", "Discovery Bay", "Sai Kung",
    ]
    
    address_lower = address.lower()
    for district in hk_districts:
        if district.lower() in address_lower:
            return district
    
    return None
