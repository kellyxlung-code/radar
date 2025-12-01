#!/usr/bin/env python3
"""
Radar Test Data Seeder (Google Places Integration)

This script seeds test data using the REAL Google Places flow:
1. Sends only lightweight candidate info (name + district)
2. Backend fetches canonical data from Google
3. Backend saves enriched place to database

This is exactly how real users will pin places from Instagram/RED.

Usage:
    python3 seed_with_google_places.py
"""

import requests
import json
import time

# ============================================================================
# CONFIGURATION
# ============================================================================

# Your backend URL (Railway or local)
API_BASE_URL = "https://awake-unity-production-0f2e.up.railway.app"

# Test user credentials
TEST_PHONE = "12345678"
TEST_PASSWORD = "test123"

# Sample Hong Kong venues (LIGHTWEIGHT - just name + district!)
SAMPLE_PLACES = [
    {
        "name": "Bar Leone",
        "district": "Central",
        "category_hint": "bar",
        "caption": "Best cocktails in Central! 🍸",
        "author": "@foodie_hk",
        "source_type": "instagram",
        "source_url": "https://instagram.com/p/example1"
    },
    {
        "name": "Carbone",
        "district": "Central",
        "category_hint": "restaurant",
        "caption": "Italian fine dining at its best 🍝",
        "author": "@hk_eats",
        "source_type": "instagram",
        "source_url": "https://instagram.com/p/example2"
    },
    {
        "name": "Halfway Coffee",
        "district": "Sheung Wan",
        "category_hint": "cafe",
        "caption": "Perfect flat white ☕",
        "author": "@coffee_lover",
        "source_type": "instagram",
        "source_url": "https://instagram.com/p/example3"
    },
    {
        "name": "Ping Pong 129",
        "district": "Sai Ying Pun",
        "category_hint": "bar",
        "caption": "Hidden gem for drinks 🍹",
        "author": "@hk_nightlife",
        "source_type": "red",
        "source_url": "https://xiaohongshu.com/example4"
    },
    {
        "name": "Lee Tung Avenue",
        "district": "Wan Chai",
        "category_hint": "activity",
        "caption": "Beautiful street art and shops 🎨",
        "author": "@explore_hk",
        "source_type": "instagram",
        "source_url": "https://instagram.com/p/example5"
    }
]


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def send_otp(phone_number: str) -> str:
    """Send OTP to phone number. Returns the OTP code."""
    url = f"{API_BASE_URL}/auth/send-otp"
    payload = {"phone_number": phone_number}

    response = requests.post(url, json=payload)
    response.raise_for_status()

    data = response.json()
    otp_code = data.get("mock_otp")
    if not otp_code:
        raise RuntimeError("send-otp response missing mock_otp")
    return otp_code


def verify_otp_and_login(phone_number: str, otp: str, password: str) -> str:
    """Verify OTP and login. Returns JWT access token."""
    url = f"{API_BASE_URL}/auth/verify-otp"
    payload = {
        "phone_number": phone_number,
        "otp_code": otp,      # <— rename key
        "password": password
    }

    response = requests.post(url, json=payload)
    response.raise_for_status()

    data = response.json()
    return data["access_token"]
    
    response = requests.post(url, json=payload)
    response.raise_for_status()
    
    data = response.json()
    return data["access_token"]


def pin_place(candidate: dict, token: str) -> dict:
    """
    Pin a place using the /pin-place endpoint.

    Backend will:
    1. Search Google Places for this name + district
    2. Fetch full details (lat, lng, address, hours, photos, rating)
    3. Save enriched place to database
    4. Return full place data
    """
    url = f"{API_BASE_URL}/pin-place"
    headers = {"Authorization": f"Bearer {token}"}
    payload = {"candidate": candidate}

    response = requests.post(url, json=payload, headers=headers)

    try:
        response.raise_for_status()
    except requests.exceptions.HTTPError:
        print("DEBUG pin-place status:", response.status_code)
        print("DEBUG pin-place text:", response.text[:500])
        raise

    if not response.text.strip():
        raise RuntimeError("Empty response body from /pin-place")

    return response.json()

def get_pinned_places(token: str) -> list:
    """Get all pinned places for the current user."""
    url = f"{API_BASE_URL}/places?pinned_only=true"
    headers = {"Authorization": f"Bearer {token}"}
    
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    
    return response.json()


# ============================================================================
# MAIN SEEDING FLOW
# ============================================================================

def main():
    print("🚀 Radar Test Data Seeder (Google Places Integration)")
    print("=" * 60)
    print()
    
    try:
        # Step 1: Send OTP
        print("1️⃣  Sending OTP...")
        otp = send_otp(TEST_PHONE)
        print(f"✅ OTP sent: {otp}")
        print(f"   (In production, user receives this via SMS)")
        print()
        
        # Step 2: Verify OTP and login
        print("2️⃣  Verifying OTP and logging in...")
        token = verify_otp_and_login(TEST_PHONE, otp, TEST_PASSWORD)
        print(f"✅ Logged in! JWT: {token[:50]}...")
        print()
        
        # Step 3: Pin places (using Google Places enrichment!)
        print("3️⃣  Pinning places (fetching from Google Places)...")
        print()
        
        pinned_places = []
        for i, candidate in enumerate(SAMPLE_PLACES, 1):
            print(f"  [{i}/{len(SAMPLE_PLACES)}] Pinning: {candidate['name']}")
            print(f"      District: {candidate['district']}")
            print(f"      Hint: {candidate['category_hint']}")
            print(f"      🔍 Searching Google Places...")
            
            try:
                result = pin_place(candidate, token)
                pinned_places.append(result)
                
                print(f"      ✅ Pinned successfully!")
                print(f"         Name: {result['name']}")
                print(f"         Address: {result.get('address', 'N/A')[:50]}...")
                print(f"         Category: {result.get('category')} {result.get('category_emoji')}")
                print(f"         Rating: {result.get('rating')} ⭐")
                print(f"         Photo: {'Yes' if result.get('photo_url') else 'No'}")
                print()
                
                # Rate limit: don't hammer Google API
                time.sleep(0.5)
                
            except requests.exceptions.HTTPError as e:
                print(f"      ❌ Failed: {e.response.json().get('detail', str(e))}")
                print()
        
        print(f"✅ Pinned {len(pinned_places)}/{len(SAMPLE_PLACES)} places")
        print()
        
        # Step 4: Verify places were saved
        print("4️⃣  Verifying places in database...")
        all_places = get_pinned_places(token)
        print(f"✅ Found {len(all_places)} pinned places:")
        
        for place in all_places:
            category = place.get('category', 'Unknown')
            emoji = place.get('category_emoji', '📍')
            name = place.get('name', 'Unknown')
            district = place.get('district', 'Unknown')
            rating = place.get('rating', 'N/A')
            
            print(f"  {emoji} {name} - {category} ({district}) - {rating}⭐")
        
        print()
        print("=" * 60)
        print("🎉 Test data seeding complete!")
        print()
        print("📊 Summary:")
        print(f"   • Backend: {API_BASE_URL}")
        print(f"   • Test phone: +852 {TEST_PHONE}")
        print(f"   • Test password: {TEST_PASSWORD}")
        print(f"   • Places pinned: {len(pinned_places)}")
        print()
        print("🔍 How it worked:")
        print("   1. Script sent only name + district (lightweight)")
        print("   2. Backend searched Google Places")
        print("   3. Backend fetched full details (lat, lng, hours, photos, rating)")
        print("   4. Backend saved enriched data to database")
        print()
        print("✨ This is exactly how real users will pin places from Instagram/RED!")
        print()
        
    except requests.exceptions.RequestException as e:
        print()
        print("=" * 60)
        print("❌ Error during seeding:")
        print(f"   {e}")
        print()
        print("💡 Troubleshooting:")
        print("   1. Is your backend running?")
        print(f"      Check: {API_BASE_URL}")
        print("   2. Is GOOGLE_PLACES_KEY set in Railway?")
        print("   3. Did you add google_places_helper.py to backend?")
        print("   4. Did you add /pin-place endpoint to main.py?")
        print()
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
