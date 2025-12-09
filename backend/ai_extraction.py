"""
Radar Backend - AI Extraction
Extract place info from Instagram/social posts using Azure OpenAI
"""

import os
import logging
import json
from typing import Optional, Dict, List
import httpx
from openai import AzureOpenAI
import re
from ai_extraction_helpers import extract_district

logger = logging.getLogger(__name__)

# Azure OpenAI Configuration
client = AzureOpenAI(
    api_key=os.getenv("AZURE_OPENAI_KEY"),
    api_version="2024-10-21",
    azure_endpoint="https://hkust.azure-api.net"
)
logger.info("✅ Azure OpenAI client initialized")


async def fetch_instagram_metadata(url: str) -> Optional[Dict]:
    """
    Fetch Instagram post metadata using Microlink API
    Returns caption, images, and any geo data
    """
    try:
        async with httpx.AsyncClient(timeout=15.0) as http_client:
            response = await http_client.get(
                "https://api.microlink.io",
                params={
                    "url": url,
                    "screenshot": "false",
                    "meta": "true",
                }
            )
            response.raise_for_status()
            data = response.json()
        
        if data.get("status") != "success":
            logger.warning(f"⚠️ Microlink API error: {data.get('status')}")
            return None
        
        metadata = data.get("data", {})
        
        return {
            "title": metadata.get("title"),
            "description": metadata.get("description"),
            "image": metadata.get("image", {}).get("url"),
            "url": url,
        }
    
    except Exception as e:
        logger.error(f"❌ Error fetching Instagram metadata: {e}")
        return None


def extract_place_from_caption(caption: str, url: str = None) -> Optional[Dict]:
    """
    Extract place information from Instagram caption.
    
    Strategy:
    1. Look for 📍 emoji (most reliable)
    2. Use OpenAI to extract from caption
    3. Return structured data
    """
    # Method 1: Check for 📍 pin emoji
    # Match place name after 📍, stop before common descriptive words, @mentions, #hashtags, Chinese text, or newlines
    # Includes: English, numbers, Vietnamese (Latin Extended), common punctuation (&, ', -)
    pin_pattern = r'📍\s*([a-zA-Z0-9\u00C0-\u024F\u1E00-\u1EFF\s,\.\-&\']+?)(?=\s+(?:captured|at|in|with|for|and|the|is|was|has|had|have|their|this|that|my|our|your)\b|\s+[@#]|\s+[\u4e00-\u9fff]|\n|$)'
    pin_match = re.search(pin_pattern, caption)
    
    if pin_match:
        place_name = pin_match.group(1).strip()
        # Clean up trailing punctuation and whitespace
        place_name = re.sub(r'[\s,;:.!?-]+$', '', place_name)
        place_name = place_name.strip()
        logger.info(f"✅ Found pin emoji: {place_name}")
        
        # Extract district
        district = extract_district(caption)
        
        return {
            "name": place_name,
            "district": district,
            "confidence": 0.95,
            "method": "pin_emoji"
        }
    
    # Method 2: Use AI extraction
    
    prompt = f"""Extract the restaurant, cafe, or bar name from this Instagram caption.

Caption: {caption}

Rules:
- Look for mentions of restaurants, cafes, bars, or venues
- Return ONLY the place name
- If a Hong Kong district is mentioned (Central, TST, Wan Chai, etc.), include it
- If no place is mentioned, return "NONE"

Format:
Place: [name]
District: [district or NONE]
Category: [eat/cafes/bars/shops/leisure/go_out/nature/culture]
"""

    try:
        response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": "You are a helpful assistant that extracts structured data from text. Always respond with valid JSON only."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=500,
        )
        
        result_text = response.choices[0].message.content.strip()
        
        # Parse response
        place_match = re.search(r'Place:\s*(.+)', result_text)
        district_match = re.search(r'District:\s*(.+)', result_text)
        category_match = re.search(r'Category:\s*(.+)', result_text)
        
        place_name = place_match.group(1).strip() if place_match else None
        district = district_match.group(1).strip() if district_match else None
        category = category_match.group(1).strip() if category_match else "eat"
        
        if not place_name or place_name.upper() == "NONE":
            logger.warning("⚠️ AI could not extract place name")
            return None
        
        if district and district.upper() == "NONE":
            district = None
        
        logger.info(f"✅ AI extracted: {place_name}")
        
        return {
            "name": place_name,
            "district": district,
            "category": category,
            "confidence": 0.85,
            "method": "ai_extraction"
        }
    
    
    
    except Exception as e:
        logger.error(f"❌ Error in AI extraction: {e}")
        return None


async def process_instagram_url(url: str) -> Optional[Dict]:
    """
    Complete flow: Fetch metadata + Extract place info
    Returns structured place data ready for Google Places enrichment
    """
    # Step 1: Fetch Instagram metadata
    metadata = await fetch_instagram_metadata(url)
    if not metadata:
        logger.warning(f"⚠️ Could not fetch metadata from: {url}")
        return None
    
    # Step 2: Extract place info from caption
    caption = metadata.get("description") or metadata.get("title") or ""
    if not caption:
        logger.warning("⚠️ No caption found in post")
        return None
    
    # FIXED: Removed 'await' since extract_place_from_caption is NOT async
    place_info = extract_place_from_caption(caption, url)
    if not place_info:
        return None
    
    # Add source metadata
    place_info["source_url"] = url
    place_info["source_platform"] = "instagram"
    place_info["source_caption"] = caption
    place_info["source_image"] = metadata.get("image")
    
    return place_info


# Fallback: Manual extraction patterns (if AI disabled)
def extract_place_manual(caption: str) -> Optional[Dict]:
    """
    Fallback manual extraction using pattern matching
    Used when AI is not available
    """
    # Simple keyword-based extraction
    caption_lower = caption.lower()
    
    # Try to find common patterns
    # This is very basic - AI is much better!
    
    category = "eat"  # Default
    tags = []
    
    if any(word in caption_lower for word in ["cafe", "coffee", "espresso"]):
        category = "cafes"
        tags.append("cafe")
    
    if any(word in caption_lower for word in ["bar", "cocktail", "wine"]):
        category = "bars"
        tags.append("bar")
    
    if any(word in caption_lower for word in ["aesthetic", "minimal", "vibe"]):
        tags.append("aesthetic")
    
    # Try to extract district
    districts = ["central", "tst", "wan chai", "mong kok", "causeway bay"]
    district = None
    for d in districts:
        if d in caption_lower:
            district = d.title()
            break
    
    return {
        "category": category,
        "tags": tags,
        "district": district,
        "description": caption[:200],  # First 200 chars
    }
