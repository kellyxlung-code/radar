from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

import os
import re
import json
import requests
import time
import logging
import traceback
import googlemaps

from sqlalchemy import or_
from sqlalchemy.orm import Session
from sqlalchemy.sql import func
from starlette.requests import Request
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# --------- LOAD LOCAL MODULES IN SAFE ORDER (to avoid circular imports) ----------
from database import Base, engine, SessionLocal
from models import User, Place

# Routers MUST be imported *after* database/models
from auth import router as auth_router
from auth import get_current_user
from pin_place_endpoint import router as pin_router

# -------------------------
# Logging
# -------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler()],
)
logger = logging.getLogger(__name__)

# -------------------------
# Environment
# -------------------------

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

GOOGLE_PLACES_KEY = os.getenv("GOOGLE_PLACES_KEY", "").strip()
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT", "").strip()
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY", "").strip()
AZURE_OPENAI_DEPLOYMENT = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4o-mini").strip()
MICROLINK_API = os.getenv("MICROLINK_API", "https://api.microlink.io?url=").strip()

if not GOOGLE_PLACES_KEY:
    logger.warning("⚠️ GOOGLE_PLACES_KEY not set.")
if not AZURE_OPENAI_ENDPOINT or not AZURE_OPENAI_KEY:
    logger.warning("⚠️ Azure OpenAI config not fully set.")

# -------------------------
# App + CORS
# -------------------------

app = FastAPI(title="Radar API")

app.include_router(auth_router)
app.include_router(pin_router, tags=["places"])

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)

# -------------------------
# Database init
# -------------------------

try:
    Base.metadata.create_all(bind=engine)
    logger.info("✅ Tables created/verified.")
except Exception as e:
    logger.error(f"❌ Table creation error: {e}")
    logger.error(traceback.format_exc())

# -------------------------
# DB dependency
# -------------------------

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# -------------------------
# Pydantic Models
# -------------------------

class ImportIn(BaseModel):
    url: str

class PinPlaceIn(BaseModel):
    candidate: Dict[str, Any]

class PlaceOut(BaseModel):
    id: int
    name: str
    lat: float
    lng: float
    is_pinned: bool
    category_emoji: Optional[str] = "📍"

class PlaceDetailsOut(BaseModel):
    id: int
    name: str
    lat: float
    lng: float
    is_pinned: bool
    category_emoji: Optional[str] = "📍"

    address: Optional[str] = None
    place_id: Optional[str] = None
    category: Optional[str] = None
    photo_url: Optional[str] = None
    rating: Optional[float] = None
    user_ratings_total: Optional[int] = None
    caption: Optional[str] = None
    source_url: Optional[str] = None
    notes: Optional[str] = None
    author: Optional[str] = None
    source_type: Optional[str] = None
    post_image_url: Optional[str] = None
    post_video_url: Optional[str] = None
    confidence: Optional[float] = None
    extraction_method: Optional[str] = None
    district: Optional[str] = None
    is_open_now: Optional[bool] = None

    class Config:
        from_attributes = True

class PlaceInUpdate(BaseModel):
    name: Optional[str] = None
    category: Optional[str] = None
    category_emoji: Optional[str] = None
    notes: Optional[str] = None
    is_pinned: Optional[bool] = None

# Chat API models
class ChatIn(BaseModel):
    message: str
    history: Optional[List[Dict[str, str]]] = None  # [{role, content}]

class ChatOut(BaseModel):
    reply: str

# -------------------------
# Middleware & Health
# -------------------------

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    logger.info(f"➡️ {request.method} {request.url.path}")
    try:
        response = await call_next(request)
    except Exception as e:
        logger.exception(f"❌ Error while handling {request.method} {request.url.path}: {e}")
        raise
    process_time = (time.time() - start_time) * 1000
    logger.info(
        f"✅ {request.method} {request.url.path} completed in {process_time:.2f} ms → {response.status_code}"
    )
    return response

@app.get("/health")
def health():
    return {"ok": True}

# -------------------------
# Social content fetch (Microlink)
# -------------------------

def fetch_social_content(url: str) -> dict:
    data = {
        "source_url": url,
        "source_type": "manual",
        "caption": "",
        "author": "",
        "post_image_url": None,
        "post_video_url": None,
    }

    if "instagram.com" in url:
        data["source_type"] = "instagram"
    elif "xiaohongshu.com" in url or "red." in url:
        data["source_type"] = "red"
    elif "tiktok.com" in url:
        data["source_type"] = "tiktok"

    try:
        r = requests.get(MICROLINK_API + requests.utils.quote(url, safe=""), timeout=10)
        if r.ok:
            microlink = r.json().get("data", {})
            if not data["caption"]:
                data["caption"] = (
                    microlink.get("description", microlink.get("title", "")) or ""
                ).strip()
            if microlink.get("video", {}).get("url"):
                data["post_video_url"] = microlink["video"]["url"]
            elif microlink.get("image", {}).get("url"):
                data["post_image_url"] = microlink["image"]["url"]
            data["author"] = microlink.get("publisher", "") or ""
            logger.info("✅ Microlink content fetch success.")
    except Exception as e:
        logger.error(f"❌ Microlink failed: {e}")

    data["caption"] = re.sub(r"\s+", " ", data["caption"]).strip()
    return data

# -------------------------
# AI Vision (Azure GPT‑4o) for import
# -------------------------

def call_azure_openai_extract(text: str, image_url: str = None) -> List[dict]:
    if not (AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY):
        logger.warning("⚠️ Azure keys missing. Cannot run AI extraction.")
        return []

    prompt = f"""
You are an expert location extractor.

Extract ALL unique, concrete venues (restaurants, bars, shops, landmarks) mentioned in this social media post (caption and image).

RULES:
1. Maximum 5 unique venues. If none are found, return an empty array [].
2. Provide an exact name and a search query optimized for Google Places (MUST include "Hong Kong").
3. Estimate confidence (0.0-1.0).

Post caption: {text}

Return ONLY a JSON array, no explanation, with this schema:
[{{ "name": "Exact Venue Name", "query": "Venue Name + District + Hong Kong", "confidence": 0.8 }}]
"""

    try:
        headers = {"Content-Type": "application/json", "api-key": AZURE_OPENAI_KEY}
        url = (
            f"{AZURE_OPENAI_ENDPOINT}deployments/"
            f"{AZURE_OPENAI_DEPLOYMENT}/chat/completions"
            f"?api-version=2025-02-01-preview"
        )

        content: List[dict] = [{"type": "text", "text": prompt}]
        if image_url:
            content.append({"type": "image_url", "image_url": {"url": image_url}})

        payload = {
            "messages": [{"role": "user", "content": content}],
            "temperature": 0.2,
            "max_tokens": 500,
            "response_format": {"type": "json_object"},
        }

        r = requests.post(url, headers=headers, data=json.dumps(payload), timeout=30)
        r.raise_for_status()
        response = r.json()

        raw_content = response["choices"][0]["message"]["content"].strip()

        if raw_content.startswith("{"):
            parsed = json.loads(raw_content)
            raw_candidates = parsed.get("candidates") or parsed.get("venues") or []
        elif raw_content.startswith("["):
            raw_candidates = json.loads(raw_content)
        else:
            raw_candidates = []

        if isinstance(raw_candidates, list):
            valid = [
                c
                for c in raw_candidates
                if isinstance(c, dict) and c.get("name") and c.get("query")
            ]
        else:
            valid = []

        logger.info(f"✅ AI extracted {len(valid)} candidates.")
        return valid
    except Exception as e:
        logger.error(f"❌ Azure Vision extract error: {e}")
        logger.error(traceback.format_exc())
        return []

# -------------------------
# Google Places
# -------------------------

HK_DISTRICTS = [
    "Central",
    "Sheung Wan",
    "Sai Ying Pun",
    "Kennedy Town",
    "Wan Chai",
    "Causeway Bay",
    "North Point",
    "Tin Hau",
    "Quarry Bay",
    "Tai Koo",
    "Tsim Sha Tsui",
    "Mong Kok",
    "Sham Shui Po",
    "Jordan",
    "Yau Ma Tei",
    "Prince Edward",
    "Kwun Tong",
    "Kowloon Bay",
    "Ngau Tau Kok",
    "Lai Chi Kok",
    "Tung Chung",
    "Discovery Bay",
    "Taikoo Shing",
]

def _infer_district(text: str) -> str:
    low = text.lower()
    for d in HK_DISTRICTS:
        if d.lower() in low:
            return d
    return ""

def _categorize_place(types: List[str]) -> tuple:
    types = [t.lower() for t in types]
    if "food" in types or "restaurant" in types or "meal_takeaway" in types:
        return "Restaurant", "🍽️"
    if "bar" in types or "night_club" in types:
        return "Bar", "🍸"
    if "cafe" in types or "bakery" in types:
        return "Coffee/Cafe", "☕️"
    if "store" in types or "shopping_mall" in types:
        return "Shop", "🛍️"
    if "gym" in types or "park" in types or "spa" in types:
        return "Activity", "🎯"
    return "Other", "📍"

def google_places_text_search(query: str) -> dict:
    if not GOOGLE_PLACES_KEY:
        return {"ok": False, "reason": "NO_GOOGLE_KEY"}

    q = query
    if "hong kong" not in q.lower():
        q = f"{q} Hong Kong"

    try:
        find_place_params = {
            "input": q,
            "inputtype": "textquery",
            "fields": "place_id",
            "key": GOOGLE_PLACES_KEY,
        }
        r_find = requests.get(
            "https://maps.googleapis.com/maps/api/place/findplacefromtext/json",
            params=find_place_params,
            timeout=10,
        )
        r_find.raise_for_status()
        find_data = r_find.json()
        candidates = find_data.get("candidates")
        if not candidates:
            logger.warning(f"⚠️ Google Find Place found no candidate for: {q}")
            return {"ok": False, "reason": "NO_CANDIDATES"}

        place_id = candidates[0]["place_id"]

        params = {
            "place_id": place_id,
            "key": GOOGLE_PLACES_KEY,
            "fields": (
                "name,formatted_address,geometry/location,place_id,photos,"
                "types,rating,user_ratings_total,opening_hours"
            ),
        }
        r_details = requests.get(
            "https://maps.googleapis.com/maps/api/place/details/json",
            params=params,
            timeout=10,
        )
        r_details.raise_for_status()
        data = r_details.json()
        result = data.get("result")
        if not result:
            logger.warning(f"⚠️ Google Details returned no result for place_id: {place_id}")
            return {"ok": False, "reason": "NO_FULL_DETAILS"}

        loc = result["geometry"]["location"]
        category, category_emoji = _categorize_place(result.get("types", []))

        photos = []
        for p in result.get("photos", [])[:3]:
            ref = p.get("photo_reference")
            if ref:
                photo_url = (
                    "https://maps.googleapis.com/maps/api/place/photo"
                    f"?maxwidth=400&photo_reference={ref}&key={GOOGLE_PLACES_KEY}"
                )
                photos.append(photo_url)

        opening_hours = result.get("opening_hours", {})
        return {
            "ok": True,
            "name": result.get("name"),
            "lat": loc["lat"],
            "lng": loc["lng"],
            "address": result.get("formatted_address", ""),
            "place_id": result.get("place_id"),
            "district": _infer_district(result.get("formatted_address", "")),
            "category": category,
            "category_emoji": category_emoji,
            "photo_url": photos[0] if photos else None,
            "photos": photos,
            "opening_hours": opening_hours,
            "is_open_now": opening_hours.get("open_now"),
            "rating": result.get("rating"),
            "user_ratings_total": result.get("user_ratings_total"),
        }
    except Exception as e:
        logger.error(f"❌ Google Places error: {e}")
        logger.error(traceback.format_exc())
        return {"ok": False, "reason": "ERROR"}

# -------------------------
# Core API Endpoints (places)
# -------------------------

@app.get("/places", response_model=List[PlaceOut])
def list_places(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    places = (
        db.query(Place)
        .filter(Place.owner_id == current_user.id, Place.is_pinned == True)
        .all()
    )
    out = [
        {
            "id": p.id,
            "name": p.name,
            "lat": p.lat,
            "lng": p.lng,
            "is_pinned": p.is_pinned,
            "category_emoji": p.category_emoji,
        }
        for p in places
    ]
    logger.info(f"✅ Returning {len(out)} pinned places for user {current_user.id}")
    return out

@app.get("/places/{place_id}", response_model=PlaceDetailsOut)
def get_place_details(
    place_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place = (
        db.query(Place)
        .filter(Place.id == place_id, Place.owner_id == current_user.id)
        .first()
    )
    if not place:
        raise HTTPException(
            status_code=404,
            detail=f"Place with ID {place_id} not found for this user.",
        )
    logger.info(f"✅ Retrieved details for place id={place_id}")
    return place

@app.get("/places/search", response_model=List[PlaceDetailsOut])
def search_places(
    q: str = Query(..., min_length=1, description="Search query"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    search_term = f"%{q.lower()}%"
    places = (
        db.query(Place)
        .filter(
            Place.owner_id == current_user.id,
            or_(
                func.lower(Place.name).like(search_term),
                func.lower(Place.caption).like(search_term),
                func.lower(Place.notes).like(search_term),
            ),
        )
        .all()
    )
    logger.info(
        f"✅ Found {len(places)} places matching '{q}' for user {current_user.id}"
    )
    return places

# -------------------------
# Import URL + Pin Place
# -------------------------

@app.post("/import-url")
def import_url(
    body: ImportIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    url = (body.url or "").strip()
    if not url:
        raise HTTPException(status_code=400, detail="Missing URL")

    social_data = fetch_social_content(url)
    image_to_analyze = social_data["post_image_url"]
    ai_candidates = call_azure_openai_extract(social_data["caption"], image_to_analyze)

    final_candidates = []
    for idx, cand in enumerate(ai_candidates):
        query = cand.get("query") or cand.get("name")
        if not query:
            continue
        gp = google_places_text_search(query)
        if not gp.get("ok"):
            continue

        temp_id = f"temp_{idx+1}"

        final_candidates.append(
            {
                "id": temp_id,
                "name": gp["name"],
                "lat": gp["lat"],
                "lng": gp["lng"],
                "district": gp.get("district"),
                "category": gp.get("category"),
                "category_emoji": gp.get("category_emoji"),
                "address": gp.get("address"),
                "photo_url": gp.get("photo_url"),
                "is_open_now": gp.get("is_open_now"),
                "rating": gp.get("rating"),
                "user_ratings_total": gp.get("user_ratings_total"),
                "place_id": gp.get("place_id"),
                "confidence": cand.get("confidence"),
                "source_url": social_data["source_url"],
                "source_type": social_data["source_type"],
                "caption": social_data["caption"],
                "author": social_data["author"],
                "post_image_url": social_data["post_image_url"],
                "post_video_url": social_data["post_video_url"],
            }
        )

    return {
        "ok": True,
        "post": {
            "caption": social_data["caption"],
            "author": social_data["author"],
            "image_url": social_data["post_image_url"],
            "video_url": social_data["post_video_url"],
        },
        "candidates": final_candidates,
        "total_found": len(final_candidates),
    }

@app.put("/places/{place_id}", response_model=PlaceDetailsOut)
def update_place(
    place_id: int,
    body: PlaceInUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    place = (
        db.query(Place)
        .filter(Place.id == place_id, Place.owner_id == current_user.id)
        .first()
    )
    if not place:
        raise HTTPException(status_code=404, detail="Place not found")

    if body.name is not None:
        place.name = body.name
    if body.category is not None:
        place.category = body.category
    if body.category_emoji is not None:
        place.category_emoji = body.category_emoji
    if body.notes is not None:
        place.notes = body.notes
    if body.is_pinned is not None:
        place.is_pinned = body.is_pinned

    db.commit()
    db.refresh(place)

    logger.info(f"✅ Updated place id={place.id} for user {current_user.id}")
    return place

# -------------------------
# Chat endpoint (for ChatView)
# -------------------------

@app.post("/chat", response_model=ChatOut)
def chat_with_radar(
    body: ChatIn,
    current_user: User = Depends(get_current_user),
):
    """
    Simple chat endpoint backed by Azure OpenAI GPT‑4o.

    Expects:
      { "message": "...", "history": [{ "role": "user"/"assistant"/"system", "content": "..." }] }

    Returns:
      { "reply": "..." }
    """
    if not (AZURE_OPENAI_ENDPOINT and AZURE_OPENAI_KEY):
        raise HTTPException(status_code=500, detail="Azure OpenAI not configured")

    try:
        headers = {"Content-Type": "application/json", "api-key": AZURE_OPENAI_KEY}
        url = (
            f"{AZURE_OPENAI_ENDPOINT}deployments/"
            f"{AZURE_OPENAI_DEPLOYMENT}/chat/completions"
            f"?api-version=2025-02-01-preview"
        )

        messages: List[Dict[str, Any]] = []

        # System prompt tuned for Radar
        messages.append(
            {
                "role": "system",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            "You are Radar, an AI assistant helping a Gen Z user "
                            "discover and remember places in Hong Kong based on their saved map. "
                            "Be short, friendly, and suggest specific areas and venues, but never invent places "
                            "that obviously don't exist. If unsure, ask a follow-up question."
                        ),
                    }
                ],
            }
        )

        # Optional history
        if body.history:
            for m in body.history:
                role = m.get("role", "user")
                content = m.get("content", "")
                messages.append(
                    {"role": role, "content": [{"type": "text", "text": content}]}
                )

        # Current user message
        messages.append(
            {
                "role": "user",
                "content": [{"type": "text", "text": body.message}],
            }
        )

        payload = {
            "messages": messages,
            "temperature": 0.6,
            "max_tokens": 300,
        }

        r = requests.post(url, headers=headers, data=json.dumps(payload), timeout=30)
        r.raise_for_status()
        data = r.json()

        reply = (
            data["choices"][0]["message"]["content"]
            if data.get("choices")
            else "Sorry, I couldn't think of anything to say."
        )
        # If Azure returns structured content, flatten it to plain text
        if isinstance(reply, list):
            text_parts = []
            for part in reply:
                if isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
            reply = " ".join(text_parts).strip() or "Sorry, I couldn't think of anything to say."

        return ChatOut(reply=reply)
    except Exception as e:
        logger.error(f"❌ Chat endpoint error: {e}")
        logger.error(traceback.format_exc())
        raise HTTPException(status_code=500, detail="Chat service error")

@app.get("/search-places")
def search_places_google(
    q: str,
    current_user: User = Depends(get_current_user),
):
    """
    Google Places Autocomplete search
    Returns list of place suggestions as user types
    """
    if not q or len(q) < 2:
        return {"results": []}
    
    google_api_key = os.getenv("GOOGLE_PLACES_KEY")
    if not google_api_key:
        raise HTTPException(status_code=500, detail="Google API key not configured")
    
    try:
        gmaps = googlemaps.Client(key=Config.GOOGLE_MAPS_API_KEY)
        
        # Autocomplete search (biased to Hong Kong)
        results = gmaps.places_autocomplete(
            input_text=q,
            location=(22.3193, 114.1694),  # Hong Kong center
            radius=50000,  # 50km radius
            components={"country": "hk"}  # Restrict to Hong Kong
        )
        
        # Format results for iOS
        formatted_results = []
        for result in results[:10]:  # Limit to top 10
            formatted_results.append({
                "place_id": result.get("place_id"),
                "name": result.get("structured_formatting", {}).get("main_text", ""),
                "address": result.get("description", ""),
                "types": result.get("types", [])
            })
        
        return {"results": formatted_results}
    
    except Exception as e:
        print(f"Google Places search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/place-details/{place_id}")
def get_place_details(
    place_id: str,
    current_user: User = Depends(get_current_user),
):
    """
    Get full details for a Google Place ID
    Returns coordinates, photos, hours, etc.
    """
    google_api_key = os.getenv("GOOGLE_PLACES_KEY")
    if not google_api_key:
        raise HTTPException(status_code=500, detail="Google API key not configured")
    
    try:
        gmaps = googlemaps.Client(key=google_api_key)
        
        # Get place details
        result = gmaps.place(
            place_id=place_id,
            fields=[
                "name", "formatted_address", "geometry", "photos",
                "opening_hours", "rating", "types", "website",
                "formatted_phone_number"
            ]
        )
        
        if result["status"] != "OK":
            raise HTTPException(status_code=404, detail="Place not found")
        
        place = result["result"]
        location = place.get("geometry", {}).get("location", {})
        
        # Get photo URL if available
        photo_url = None
        if place.get("photos"):
            photo_reference = place["photos"][0].get("photo_reference")
            if photo_reference:
                photo_url = f"https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference={photo_reference}&key={google_api_key}"
        
        # Parse opening hours
        opening_hours = None
        is_open_now = None
        if place.get("opening_hours"):
            opening_hours = place["opening_hours"].get("weekday_text")
            is_open_now = place["opening_hours"].get("open_now")
        
        # Determine category from types
        category = "Other"
        category_emoji = "📍"
        types = place.get("types", [])
        
        if "bar" in types or "night_club" in types:
            category = "Bar"
            category_emoji = "🍸"
        elif "restaurant" in types or "food" in types:
            category = "Restaurant"
            category_emoji = "🍽️"
        elif "cafe" in types or "coffee" in types:
            category = "Cafe"
            category_emoji = "☕"
        elif "tourist_attraction" in types or "point_of_interest" in types:
            category = "Activity"
            category_emoji = "🎭"
        
        return {
            "place_id": place_id,
            "name": place.get("name"),
            "address": place.get("formatted_address"),
            "lat": location.get("lat"),
            "lng": location.get("lng"),
            "photo_url": photo_url,
            "opening_hours": opening_hours,
            "is_open_now": is_open_now,
            "rating": place.get("rating"),
            "category": category,
            "category_emoji": category_emoji,
            "website": place.get("website"),
            "phone": place.get("formatted_phone_number"),
            "types": types
        }
    
    except Exception as e:
        print(f"Place details error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
