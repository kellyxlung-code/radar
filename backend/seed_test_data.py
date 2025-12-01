#!/usr/bin/env python3
"""
Radar Test Data Seeder
Creates test user and pins sample places for development
"""

import requests
import json

# Your Railway backend URL
BASE_URL = "https://awake-unity-production-0f2e.up.railway.app"

# Test user credentials
TEST_PHONE = "12345678"
TEST_PASSWORD = "test123"

def main():
    print("🚀 Radar Test Data Seeder")
    print("=" * 50)
    
    # Step 1: Send OTP
    print("\n1️⃣ Sending OTP...")
    response = requests.post(f"{BASE_URL}/auth/send-otp", json={
        "phone_number": TEST_PHONE
    })
    
    if response.status_code != 200:
        print(f"❌ Failed to send OTP: {response.text}")
        return
    
    otp_data = response.json()
    otp_code = otp_data.get("mock_otp")
    print(f"✅ OTP sent: {otp_code}")
    
    # Step 2: Verify OTP and get JWT
    print("\n2️⃣ Verifying OTP and logging in...")
    response = requests.post(f"{BASE_URL}/auth/verify-otp", json={
        "phone_number": TEST_PHONE,
        "otp_code": otp_code,
        "password": TEST_PASSWORD
    })
    
    if response.status_code != 200:
        print(f"❌ Failed to verify OTP: {response.text}")
        return
    
    token_data = response.json()
    jwt_token = token_data.get("access_token")
    print(f"✅ Logged in! JWT: {jwt_token[:20]}...")
    
    headers = {
        "Authorization": f"Bearer {jwt_token}",
        "Content-Type": "application/json"
    }
    
    # Step 3: Create sample places directly
    print("\n3️⃣ Creating sample places...")
    
    sample_places = [
        {
            "name": "Bar Leone",
            "lat": 22.2815,
            "lng": 114.1554,
            "district": "Central",
            "category": "Bar",
            "category_emoji": "🍸",
            "address": "11-15 Bridges St, Central, Hong Kong",
            "source": "Instagram",
            "caption": "Amazing cocktails at Bar Leone! 🍸",
            "author": "@foodie_hk",
            "image": "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800",
            "photo_url": "https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800",
            "opening_hours": ["Monday: 5:00 PM – 12:00 AM", "Tuesday: 5:00 PM – 12:00 AM"],
            "is_open_now": 1
        },
        {
            "name": "Carbone",
            "lat": 22.2793,
            "lng": 114.1628,
            "district": "Central",
            "category": "Restaurant",
            "category_emoji": "🍽️",
            "address": "LG/F, Landmark, Central, Hong Kong",
            "source": "Instagram",
            "caption": "Best Italian in HK! The pasta is incredible 🍝",
            "author": "@hk_eats",
            "image": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
            "photo_url": "https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800",
            "opening_hours": ["Monday: 12:00 PM – 3:00 PM, 6:00 PM – 11:00 PM"],
            "is_open_now": 1
        },
        {
            "name": "Halfway Coffee",
            "lat": 22.2825,
            "lng": 114.1535,
            "district": "Sheung Wan",
            "category": "Cafe",
            "category_emoji": "☕",
            "address": "123 Hollywood Rd, Sheung Wan, Hong Kong",
            "source": "Instagram",
            "caption": "Perfect morning coffee spot ☕",
            "author": "@coffee_lover_hk",
            "image": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800",
            "photo_url": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800",
            "opening_hours": ["Monday: 8:00 AM – 6:00 PM"],
            "is_open_now": 1
        },
        {
            "name": "Ping Pong 129",
            "lat": 22.2842,
            "lng": 114.1512,
            "district": "Sai Ying Pun",
            "category": "Bar",
            "category_emoji": "🍸",
            "address": "129 Second St, Sai Ying Pun, Hong Kong",
            "source": "RED",
            "caption": "Hidden gem in SYP! Great vibes 🎉",
            "author": "@nightlife_hk",
            "image": "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800",
            "photo_url": "https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800",
            "opening_hours": ["Monday: 6:00 PM – 2:00 AM"],
            "is_open_now": 1
        },
        {
            "name": "Lee Tung Avenue",
            "lat": 22.2743,
            "lng": 114.1728,
            "district": "Wan Chai",
            "category": "Activity",
            "category_emoji": "🎭",
            "address": "200 Queen's Rd E, Wan Chai, Hong Kong",
            "source": "Instagram",
            "caption": "Beautiful street art and culture 🎨",
            "author": "@explore_hk",
            "image": "https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800",
            "photo_url": "https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800",
            "opening_hours": ["Monday: Open 24 hours"],
            "is_open_now": 1
        }
    ]
    
    created_count = 0
    for place_data in sample_places:
        # Use the /pin-place endpoint with candidate format
        candidate = {
            "name": place_data["name"],
            "lat": place_data["lat"],
            "lng": place_data["lng"],
            "district": place_data["district"],
            "category": place_data["category"],
            "category_emoji": place_data["category_emoji"],
            "address": place_data["address"],
            "source": place_data["source"],
            "caption": place_data.get("caption"),
            "author": place_data.get("author"),
            "image": place_data.get("image"),
            "photo_url": place_data.get("photo_url"),
            "opening_hours": json.dumps(place_data.get("opening_hours", [])),
            "is_open_now": place_data.get("is_open_now", 0)
        }
        
        response = requests.post(
            f"{BASE_URL}/pin-place",
            headers=headers,
            json={"candidate": candidate}
        )
        
        if response.status_code == 200:
            print(f"  ✅ Created: {place_data['name']}")
            created_count += 1
        else:
            print(f"  ❌ Failed to create {place_data['name']}: {response.text}")
    
    print(f"\n✅ Created {created_count}/{len(sample_places)} places")
    
    # Step 4: Verify places were created
    print("\n4️⃣ Verifying places...")
    response = requests.get(
        f"{BASE_URL}/places?pinned_only=true",
        headers=headers
    )
    
    if response.status_code == 200:
        places = response.json()
        print(f"✅ Found {len(places)} pinned places in database")
        for place in places:
            print(f"  📍 {place['name']} - {place['category']}")
    else:
        print(f"❌ Failed to fetch places: {response.text}")
    
    print("\n" + "=" * 50)
    print("🎉 Test data seeding complete!")
    print("\nTest credentials:")
    print(f"  Phone: +852 {TEST_PHONE}")
    print(f"  Password: {TEST_PASSWORD}")
    print(f"  JWT: {jwt_token[:30]}...")
    print("\nYou can now:")
    print("  1. Login to iOS app with these credentials")
    print("  2. See places on home screen")
    print("  3. View them on the map")

if __name__ == "__main__":
    main()
