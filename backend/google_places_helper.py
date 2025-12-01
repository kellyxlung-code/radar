"""
Google Places Helper Module for Radar Backend

This module provides functions to fetch canonical place data from Google Places API.
Radar never stores manually-entered details; it always fetches from Google.

Usage:
    from google_places_helper import fetch_place_details_from_google
    
    candidate = {
        "name": "Bar Leone",
        "district": "Central",
        "city": "Hong Kong"
    }
    
    place_data = fetch_place_details_from_google(candidate)
    # Returns enriched data with lat, lng, address, hours, photos, etc.
"""

import os
import requests
from typing import Dict, Optional, List
import logging

logger = logging.getLogger(__name__)

# Get API key from environment
GOOGLE_API_KEY = os.getenv("GOOGLE_PLACES_KEY")

def fetch_place_details_from_google(candidate: Dict) -> Optional[Dict]:
    """
    Fetch canonical place data from Google Places API.
    
    Args:
        candidate: Dict with at minimum:
            - name: str (e.g. "Bar Leone")
            - district: str (e.g. "Central") OR
            - lat: float, lng: float (approximate location)
            Optional:
            - city: str (defaults to "Hong Kong")
            - category_hint: str (e.g. "bar", "cafe")
    
    Returns:
        Dict with enriched place data:
            - place_id: str
            - name: str (canonical from Google)
            - lat: float
            - lng: float
            - address: str (formatted_address)
            - district: str (extracted from address)
            - opening_hours: str (JSON string)
            - is_open_now: int (1 or 0)
            - rating: float
            - user_ratings_total: int
            - photo_url: str (first photo)
            - types: List[str] (Google place types)
        
        Returns None if no match found.
    """
    
    if not GOOGLE_API_KEY:
        logger.error("❌ GOOGLE_PLACES_KEY not set in environment")
        return None
    
    # Step 1: Find the place using Text Search
    place_id = _find_place_by_text(candidate)
    
    if not place_id:
        logger.warning(f"⚠️ No Google place found for: {candidate.get('name')}")
        return None
    
    # Step 2: Get detailed info using Place Details
    place_details = _get_place_details(place_id)
    
    if not place_details:
        logger.warning(f"⚠️ Could not fetch details for place_id: {place_id}")
        return None
    
    # Step 3: Extract and format the data
    enriched_data = _format_place_data(place_details, candidate)
    
    logger.info(f"✅ Fetched Google data for: {enriched_data.get('name')}")
    return enriched_data


def _find_place_by_text(candidate: Dict) -> Optional[str]:
    """
    Find a place using Google Places Text Search API.
    
    Returns place_id if found, None otherwise.
    """
    
    name = candidate.get("name", "")
    district = candidate.get("district", "")
    city = candidate.get("city", "Hong Kong")
    category_hint = candidate.get("category_hint", "")
    
    # Build search query
    # Example: "Bar Leone Central Hong Kong bar"
    query_parts = [name]
    if district:
        query_parts.append(district)
    if city:
        query_parts.append(city)
    if category_hint:
        query_parts.append(category_hint)
    
    query = " ".join(query_parts)
    
    # If candidate has lat/lng, use location biasing
    location_bias = ""
    if "lat" in candidate and "lng" in candidate:
        lat = candidate["lat"]
        lng = candidate["lng"]
        location_bias = f"&location={lat},{lng}&radius=500"
    
    url = f"https://maps.googleapis.com/maps/api/place/textsearch/json?query={requests.utils.quote(query)}{location_bias}&key={GOOGLE_API_KEY}"
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get("status") == "OK" and data.get("results"):
            # Return the first (best) match
            place_id = data["results"][0].get("place_id")
            logger.info(f"🔍 Found place_id: {place_id} for query: {query}")
            return place_id
        else:
            logger.warning(f"⚠️ No results for query: {query} (status: {data.get('status')})")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error in Text Search: {e}")
        return None


def _get_place_details(place_id: str) -> Optional[Dict]:
    """
    Get detailed information about a place using Place Details API.
    
    Returns raw place details dict from Google.
    """
    
    # Request all useful fields
    fields = [
        "place_id",
        "name",
        "formatted_address",
        "geometry",
        "opening_hours",
        "rating",
        "user_ratings_total",
        "photos",
        "types",
        "vicinity"
    ]
    
    fields_param = ",".join(fields)
    url = f"https://maps.googleapis.com/maps/api/place/details/json?place_id={place_id}&fields={fields_param}&key={GOOGLE_API_KEY}"
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if data.get("status") == "OK" and data.get("result"):
            return data["result"]
        else:
            logger.warning(f"⚠️ Place Details failed: {data.get('status')}")
            return None
            
    except Exception as e:
        logger.error(f"❌ Error in Place Details: {e}")
        return None


def _format_place_data(place_details: Dict, candidate: Dict) -> Dict:
    """
    Format Google Place Details into Radar's Place model format.
    
    Merges Google's canonical data with user-provided context (caption, emoji, etc.)
    """
    
    # Extract coordinates
    geometry = place_details.get("geometry", {})
    location = geometry.get("location", {})
    lat = location.get("lat", 0.0)
    lng = location.get("lng", 0.0)
    
    # Extract address and district
    formatted_address = place_details.get("formatted_address", "")
    district = _extract_district_from_address(formatted_address) or candidate.get("district", "")
    
    # Extract opening hours
    opening_hours_data = place_details.get("opening_hours", {})
    opening_hours_json = None
    is_open_now = 0
    
    if opening_hours_data:
        # Store weekday_text as JSON string
        weekday_text = opening_hours_data.get("weekday_text", [])
        if weekday_text:
            import json
            opening_hours_json = json.dumps(weekday_text)
        
        is_open_now = 1 if opening_hours_data.get("open_now") else 0
    
    # Extract rating
    rating = place_details.get("rating")
    user_ratings_total = place_details.get("user_ratings_total")
    
    # Extract first photo
    photo_url = None
    photos = place_details.get("photos", [])
    if photos:
        photo_reference = photos[0].get("photo_reference")
        if photo_reference:
            # Build photo URL (max width 800px)
            photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photoreference={photo_reference}&key={GOOGLE_API_KEY}"
    
    # Extract types and infer category
    types = place_details.get("types", [])
    category, category_emoji = _infer_category_from_types(types, candidate.get("category_hint"))
    
    # Build enriched place data
    enriched = {
        # Google canonical data
        "place_id": place_details.get("place_id"),
        "name": place_details.get("name"),
        "lat": lat,
        "lng": lng,
        "address": formatted_address,
        "district": district,
        "opening_hours": opening_hours_json,
        "is_open_now": is_open_now,
        "rating": rating,
        "user_ratings_total": user_ratings_total,
        "photo_url": photo_url,
        "types": types,
        
        # Inferred category
        "category": category,
        "category_emoji": category_emoji,
        
        # User context (from candidate)
        "caption": candidate.get("caption"),
        "author": candidate.get("author"),
        "source_type": candidate.get("source_type"),
        "source_url": candidate.get("source_url"),
        "image": candidate.get("image"),  # User's Instagram image (different from Google photo)
    }
    
    return enriched


def _extract_district_from_address(address: str) -> Optional[str]:
    """
    Extract Hong Kong district from formatted address.
    
    Example: "11-15 Bridges St, Central, Hong Kong" → "Central"
    """
    
    # Common HK districts
    districts = [
        "Central", "Sheung Wan", "Wan Chai", "Causeway Bay",
        "Tsim Sha Tsui", "Mong Kok", "Yau Ma Tei", "Jordan",
        "Sai Ying Pun", "Kennedy Town", "Admiralty", "Quarry Bay",
        "Tai Hang", "Happy Valley", "Tin Hau", "Fortress Hill",
        "North Point", "Sai Wan Ho", "Shau Kei Wan", "Chai Wan",
        "Stanley", "Repulse Bay", "Aberdeen", "Ap Lei Chau",
        "Hung Hom", "To Kwa Wan", "Kowloon City", "Kowloon Tong",
        "Diamond Hill", "Wong Tai Sin", "Kwun Tong", "Lam Tin",
        "Sham Shui Po", "Cheung Sha Wan", "Lai Chi Kok", "Mei Foo",
        "Tsuen Wan", "Kwai Chung", "Tsing Yi", "Tuen Mun",
        "Yuen Long", "Tin Shui Wai", "Sheung Shui", "Fanling",
        "Tai Po", "Sha Tin", "Ma On Shan", "Sai Kung", "Tseung Kwan O"
    ]
    
    for district in districts:
        if district in address:
            return district
    
    return None


def _infer_category_from_types(types: List[str], hint: Optional[str] = None) -> tuple:
    """
    Infer Radar category and emoji from Google place types.
    
    Returns: (category_name, category_emoji)
    """
    
    # Use hint if provided
    if hint:
        hint_lower = hint.lower()
        if "bar" in hint_lower or "drink" in hint_lower:
            return ("Bar", "🍸")
        elif "cafe" in hint_lower or "coffee" in hint_lower:
            return ("Cafe", "☕")
        elif "restaurant" in hint_lower or "food" in hint_lower:
            return ("Restaurant", "🍽️")
        elif "activity" in hint_lower or "attraction" in hint_lower:
            return ("Activity", "🎯")
    
    # Map Google types to Radar categories
    type_mapping = {
        "bar": ("Bar", "🍸"),
        "night_club": ("Bar", "🍸"),
        "liquor_store": ("Bar", "🍸"),
        
        "cafe": ("Cafe", "☕"),
        "coffee": ("Cafe", "☕"),
        
        "restaurant": ("Restaurant", "🍽️"),
        "meal_delivery": ("Restaurant", "🍽️"),
        "meal_takeaway": ("Restaurant", "🍽️"),
        "food": ("Restaurant", "🍽️"),
        
        "tourist_attraction": ("Activity", "🎯"),
        "museum": ("Activity", "🎯"),
        "art_gallery": ("Activity", "🎯"),
        "amusement_park": ("Activity", "🎯"),
        "aquarium": ("Activity", "🎯"),
        "bowling_alley": ("Activity", "🎯"),
        "casino": ("Activity", "🎯"),
        "movie_theater": ("Activity", "🎯"),
        "night_club": ("Activity", "🎯"),
        "park": ("Activity", "🎯"),
        "spa": ("Activity", "🎯"),
        "stadium": ("Activity", "🎯"),
        "zoo": ("Activity", "🎯"),
        
        "shopping_mall": ("Shopping", "🛍️"),
        "store": ("Shopping", "🛍️"),
        "clothing_store": ("Shopping", "🛍️"),
    }
    
    # Check each type
    for place_type in types:
        if place_type in type_mapping:
            return type_mapping[place_type]
    
    # Default fallback
    return ("Place", "📍")


# ============================================================================
# TESTING FUNCTIONS (for development)
# ============================================================================

def test_google_places_integration():
    """
    Test the Google Places integration with sample Hong Kong venues.
    """
    
    print("🧪 Testing Google Places Integration\n")
    print("=" * 60)
    
    test_candidates = [
        {
            "name": "Bar Leone",
            "district": "Central",
            "city": "Hong Kong",
            "category_hint": "bar"
        },
        {
            "name": "Carbone",
            "district": "Central",
            "city": "Hong Kong",
            "category_hint": "restaurant"
        },
        {
            "name": "Halfway Coffee",
            "district": "Sheung Wan",
            "city": "Hong Kong",
            "category_hint": "cafe"
        }
    ]
    
    for candidate in test_candidates:
        print(f"\n📍 Testing: {candidate['name']}")
        print("-" * 60)
        
        result = fetch_place_details_from_google(candidate)
        
        if result:
            print(f"✅ Success!")
            print(f"   Name: {result['name']}")
            print(f"   Address: {result['address']}")
            print(f"   Coordinates: ({result['lat']}, {result['lng']})")
            print(f"   District: {result['district']}")
            print(f"   Category: {result['category']} {result['category_emoji']}")
            print(f"   Rating: {result['rating']} ({result['user_ratings_total']} reviews)")
            print(f"   Open now: {'Yes' if result['is_open_now'] else 'No'}")
            print(f"   Photo: {result['photo_url'][:80]}..." if result['photo_url'] else "   Photo: None")
        else:
            print(f"❌ Failed to fetch data")
    
    print("\n" + "=" * 60)
    print("✅ Test complete!")


if __name__ == "__main__":
    # Run tests if executed directly
    test_google_places_integration()
