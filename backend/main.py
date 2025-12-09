"""
Radar Backend - Main FastAPI Application
MVP-ready with OTP bypass, emoji categories, Instagram import
"""

# Load environment variables FIRST
from dotenv import load_dotenv
load_dotenv()

import os
import logging
from contextlib import asynccontextmanager
from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, desc
from datetime import datetime, timedelta

# Local imports
from database import init_db, get_db
from models import User, Place, Event, get_emoji_for_category, get_category_from_tags
from auth import send_otp, verify_otp, get_current_user, MVP_MODE
from google_places import enrich_place_data, extract_district_from_address
from ai_extraction import process_instagram_url, extract_place_manual
from google_places_autocomplete import autocomplete_search, get_place_details

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events"""
    # Startup
    logger.info("🚀 Starting Radar Backend...")
    await init_db()
    
    if MVP_MODE:
        logger.info("⚠️ MVP MODE ENABLED - OTP bypass active (123456)")
    
    yield
    
    # Shutdown
    logger.info("👋 Shutting down Radar Backend...")

# Create FastAPI app
app = FastAPI(
    title="Radar API",
    description="Gen Z social discovery app backend",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests"""
    logger.info(f"{request.method} {request.url.path}")
    response = await call_next(request)
    return response


# ============================================================================
# Pydantic Models (Request/Response schemas)
# ============================================================================

class SendOTPRequest(BaseModel):
    phone_number: str = Field(..., example="+85212345678")


class VerifyOTPRequest(BaseModel):
    phone_number: str = Field(..., example="+85212345678")
    otp_code: str = Field(..., example="123456")


class ImportURLRequest(BaseModel):
    url: str = Field(..., example="https://www.instagram.com/p/xxx")


class ManualPinRequest(BaseModel):
    name: str = Field(..., example="Bar Leone")
    district: Optional[str] = Field(None, example="Central")
    category: Optional[str] = Field(None, example="bars")
    tags: Optional[List[str]] = Field(None, example=["cocktail", "rooftop"])


class UpdatePlaceRequest(BaseModel):
    is_visited: Optional[bool] = None
    is_favorite: Optional[bool] = None
    user_notes: Optional[str] = None


class PlaceResponse(BaseModel):
    id: int
    name: str
    address: Optional[str]
    district: Optional[str]
    lat: float
    lng: float
    category: str
    emoji: str
    photo_url: Optional[str]
    rating: Optional[float]
    opening_hours: Optional[dict] = None  # {"weekday_text": [...], "open_now": bool}
    is_open_now: Optional[bool] = None
    place_id: Optional[str] = None  # Google place_id for fetching more photos
    is_visited: bool
    is_favorite: bool
    tags: Optional[List[str]]
    source_url: Optional[str]
    created_at: str
    
    class Config:
        from_attributes = True


def place_to_response(place) -> PlaceResponse:
    """Helper to convert Place model to PlaceResponse"""
    # Parse opening_hours JSON if exists
    opening_hours_dict = None
    is_open = None
    
    if place.opening_hours:
        import json
        if isinstance(place.opening_hours, str):
            try:
                weekday_text = json.loads(place.opening_hours)
                opening_hours_dict = {"weekday_text": weekday_text}
            except:
                pass
        elif isinstance(place.opening_hours, dict):
            opening_hours_dict = place.opening_hours
        elif isinstance(place.opening_hours, list):
            opening_hours_dict = {"weekday_text": place.opening_hours}
    
    # Check if open now (would need to be stored separately or calculated)
    # For now, just return None
    
    return PlaceResponse(
        id=place.id,
        name=place.name,
        address=place.address,
        district=place.district,
        lat=place.lat,
        lng=place.lng,
        category=place.category,
        emoji=place.emoji,
        photo_url=place.photo_url,
        rating=place.rating,
        opening_hours=opening_hours_dict,
        is_open_now=is_open,
        place_id=place.google_place_id,
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=place.source_url,
        created_at=place.created_at.isoformat(),
    )


# ============================================================================
# Health Check
# ============================================================================

@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {"ok": True, "mvp_mode": MVP_MODE}


# ============================================================================
# Authentication Endpoints
# ============================================================================

@app.post("/auth/send-otp")
async def send_otp_endpoint(
    request: SendOTPRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Send OTP to phone number
    MVP: Returns mock OTP for testing
    """
    result = await send_otp(request.phone_number, db)
    return result


@app.post("/auth/verify-otp")
async def verify_otp_endpoint(
    request: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify OTP and return JWT token
    MVP: Accept "123456" as bypass code
    """
    result = await verify_otp(request.phone_number, request.otp_code, db)
    return result


@app.get("/auth/me")
async def get_current_user_endpoint(
    current_user: User = Depends(get_current_user)
):
    """Get current authenticated user"""
    return {
        "id": current_user.id,
        "phone_number": current_user.phone_number,
        "created_at": current_user.created_at.isoformat(),
    }


# ============================================================================
# Instagram Import Endpoint
# ============================================================================

@app.post("/import-url", response_model=PlaceResponse)
async def import_url(
    request: ImportURLRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Import place from Instagram/social URL
    Flow: Fetch metadata → AI extract → Google enrich → Save
    """
    url = request.url
    
    logger.info(f"📥 Importing URL: {url}")
    
    # Step 1: AI extraction
    ai_data = await process_instagram_url(url)
    if not ai_data:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Could not extract place information from URL"
        )
    
    name = ai_data.get("name")
    district = ai_data.get("district")
    
    # Step 2: Google Places enrichment
    google_data = await enrich_place_data(name, district)
    if not google_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not find place '{name}' on Google Places"
        )
    
    # Step 3: Merge data
    # Determine category and emoji
    tags = ai_data.get("tags", [])
    category = ai_data.get("category") or get_category_from_tags(tags)
    emoji = get_emoji_for_category(category)
    
    # Extract district from Google address if not from AI
    if not district and google_data.get("address"):
        district = extract_district_from_address(google_data["address"])
    
    # Step 4: Check if place already exists for this user
    google_place_id = google_data.get("place_id")
    existing_place = await db.execute(
        select(Place).where(
            Place.user_id == current_user.id,
            Place.google_place_id == google_place_id
        )
    )
    place = existing_place.scalar_one_or_none()
    
    if place:
        # Place already exists, return it
        logger.info(f"✅ Place already exists: {place.name} ({place.emoji})")
    else:
        # Create new place
        place = Place(
            user_id=current_user.id,
            name=google_data.get("name"),
            address=google_data.get("address"),
            district=district,
            lat=google_data.get("lat"),
            lng=google_data.get("lng"),
            google_place_id=google_place_id,
            photo_url=google_data.get("photo_url"),
            rating=google_data.get("rating"),
            price_level=google_data.get("price_level"),
            opening_hours=google_data.get("opening_hours"),
            phone=google_data.get("phone"),
            website=google_data.get("website"),
            category=category,
            emoji=emoji,
            source_platform=ai_data.get("source_platform"),
            source_url=url,
            source_caption=ai_data.get("source_caption"),
            tags=tags,
        )
        
        db.add(place)
        await db.commit()
        await db.refresh(place)
        logger.info(f"✅ Saved new place: {place.name} ({place.emoji})")
    
    return place_to_response(place)


# ============================================================================
# Manual Pin Endpoint (Paste link or search)
# ============================================================================

@app.post("/pin-place", response_model=PlaceResponse)
async def pin_place(
    request: ManualPinRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Manually pin a place by name
    User types name → Google enrichment → Save
    """
    name = request.name
    district = request.district
    
    logger.info(f"📍 Pinning place: {name}")
    
    # Google Places enrichment
    google_data = await enrich_place_data(name, district)
    if not google_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Could not find place '{name}' on Google Places"
        )
    
    # Determine category and emoji
    category = request.category or get_category_from_tags(request.tags or [])
    emoji = get_emoji_for_category(category)
    
    # Extract district from Google address if not provided
    if not district and google_data.get("address"):
        district = extract_district_from_address(google_data["address"])
    
    # Save to database
    place = Place(
        user_id=current_user.id,
        name=google_data.get("name"),
        address=google_data.get("address"),
        district=district,
        lat=google_data.get("lat"),
        lng=google_data.get("lng"),
        google_place_id=google_data.get("place_id"),
        photo_url=google_data.get("photo_url"),
        rating=google_data.get("rating"),
        price_level=google_data.get("price_level"),
        opening_hours=google_data.get("opening_hours"),
        phone=google_data.get("phone"),
        website=google_data.get("website"),
        category=category,
        emoji=emoji,
        tags=request.tags or [],
    )
    
    db.add(place)
    await db.commit()
    await db.refresh(place)
    
    logger.info(f"✅ Pinned place: {place.name} ({place.emoji})")
    
    return place_to_response(place)


# ============================================================================
# Places Endpoints
# ============================================================================

@app.get("/places", response_model=List[PlaceResponse])
async def get_places(
    category: Optional[str] = None,
    district: Optional[str] = None,
    favorites_only: bool = False,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get all places for current user
    Supports filtering by category, district, favorites
    """
    # Build query
    query = select(Place).where(Place.user_id == current_user.id)
    
    if category:
        query = query.where(Place.category == category)
    
    if district:
        query = query.where(Place.district == district)
    
    if favorites_only:
        query = query.where(Place.is_favorite == True)
    
    # Order by created_at desc
    query = query.order_by(Place.created_at.desc())
    
    result = await db.execute(query)
    places = result.scalars().all()
    
    return [place_to_response(p) for p in places]


@app.get("/places/{place_id}", response_model=PlaceResponse)
async def get_place(
    place_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Get single place by ID"""
    result = await db.execute(
        select(Place).where(
            and_(Place.id == place_id, Place.user_id == current_user.id)
        )
    )
    place = result.scalar_one_or_none()
    
    if not place:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found"
        )
    
    return place_to_response(place)


@app.patch("/places/{place_id}", response_model=PlaceResponse)
async def update_place(
    place_id: int,
    request: UpdatePlaceRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Update place (mark as visited, favorite, add notes)"""
    result = await db.execute(
        select(Place).where(
            and_(Place.id == place_id, Place.user_id == current_user.id)
        )
    )
    place = result.scalar_one_or_none()
    
    if not place:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found"
        )
    
    # Update fields
    if request.is_visited is not None:
        place.is_visited = request.is_visited
    
    if request.is_favorite is not None:
        place.is_favorite = request.is_favorite
    
    if request.user_notes is not None:
        place.user_notes = request.user_notes
    
    await db.commit()
    await db.refresh(place)
    
    return place_to_response(place)


@app.delete("/places/{place_id}")
async def delete_place(
    place_id: int,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Delete a place"""
    result = await db.execute(
        select(Place).where(
            and_(Place.id == place_id, Place.user_id == current_user.id)
        )
    )
    place = result.scalar_one_or_none()
    
    if not place:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Place not found"
        )
    
    await db.delete(place)
    await db.commit()
    
    return {"message": "Place deleted successfully"}


# ============================================================================
# Categories Endpoint (For UI filters)
# ============================================================================

@app.get("/categories")
def get_categories():
    """Get all available categories with emojis"""
    from models import CATEGORY_EMOJIS
    
    return [
        {"id": key, "name": key.replace("_", " ").title(), "emoji": emoji}
        for key, emoji in CATEGORY_EMOJIS.items()
        if key != "default"
    ]


# ============================================================================
# Google Places Autocomplete (For manual search)
# ============================================================================

@app.get("/search-places")
async def search_places(
    query: str,
    current_user: User = Depends(get_current_user)
):
    """
    Search for places using Google Places Autocomplete.
    Used in Share Extension manual search.
    """
    if len(query) < 2:
        return {"results": []}
    
    results = await autocomplete_search(query)
    return {"results": results}


class AddPlaceByIdRequest(BaseModel):
    place_id: str = Field(..., example="ChIJXxYxZ...")


@app.post("/add-place-by-id")
async def add_place_by_id(
    request: AddPlaceByIdRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Add a place by Google Place ID (from autocomplete).
    Returns full place data.
    """
    # Get place details from Google
    google_data = await get_place_details(request.place_id)
    if not google_data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Could not find place details"
        )
    
    # Determine category from types
    types = google_data.get("types", [])
    category = get_category_from_tags(types)
    emoji = get_emoji_for_category(category)
    
    # Extract district
    district = extract_district_from_address(google_data.get("address", ""))
    
    # Save to database
    place = Place(
        user_id=current_user.id,
        name=google_data.get("name"),
        address=google_data.get("address"),
        district=district,
        lat=google_data.get("lat"),
        lng=google_data.get("lng"),
        google_place_id=request.place_id,
        photo_url=google_data.get("photo_url"),
        rating=google_data.get("rating"),
        price_level=google_data.get("price_level"),
        opening_hours=google_data.get("opening_hours"),
        phone=google_data.get("phone"),
        website=google_data.get("website"),
        category=category,
        emoji=emoji,
        tags=types[:5],  # Use Google types as tags
    )
    
    db.add(place)
    await db.commit()
    await db.refresh(place)
    
    logger.info(f"✅ Added place by ID: {place.name} ({place.emoji})")
    
    return place_to_response(place)


# ============================================================================
# Events Endpoint (For Home Screen)
# ============================================================================

@app.get("/events")
async def get_events(
    db: AsyncSession = Depends(get_db)
):
    """
    Get curated Hong Kong events happening now or soon.
    Manually curated from Lifestyle Asia HK.
    """
    # Get events happening now or in the future
    now = datetime.utcnow()
    result = await db.execute(
        select(Event)
        .where(Event.end_date >= now)
        .order_by(Event.start_date)
        .limit(10)
    )
    events = result.scalars().all()
    
    return [
        {
            "id": event.id,
            "name": event.name,
            "description": event.description,
            "photo_url": event.photo_url,
            "location": event.location,
            "district": event.district,
            "start_date": event.start_date.isoformat(),
            "end_date": event.end_date.isoformat(),
            "category": event.category,
            "url": event.url,
            "time_description": event.time_description
        }
        for event in events
    ]


# ============================================================================
# Trending Endpoint (For Home Screen)
# ============================================================================

@app.get("/trending")
async def get_trending(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get trending places based on velocity algorithm:
    - Recent saves (last 7 days) × 2
    - Medium-term saves (last 30 days) × 0.5
    """
    # Get all places with save counts
    result = await db.execute(
        select(Place)
        .order_by(desc(Place.created_at))
    )
    all_places = result.scalars().all()
    
    # Calculate trending scores
    now = datetime.utcnow()
    seven_days_ago = now - timedelta(days=7)
    thirty_days_ago = now - timedelta(days=30)
    
    trending_data = []
    for place in all_places:
        # Count saves in different time windows
        result_7d = await db.execute(
            select(Place)
            .where(
                and_(
                    Place.google_place_id == place.google_place_id,
                    Place.created_at >= seven_days_ago
                )
            )
        )
        saves_7d = len(result_7d.scalars().all())
        
        result_30d = await db.execute(
            select(Place)
            .where(
                and_(
                    Place.google_place_id == place.google_place_id,
                    Place.created_at >= thirty_days_ago
                )
            )
        )
        saves_30d = len(result_30d.scalars().all())
        
        # Calculate trending score
        score = (saves_7d * 2) + (saves_30d * 0.5)
        
        if score > 0:
            trending_data.append({
                "place": place,
                "score": score,
                "saves_7d": saves_7d,
                "saves_30d": saves_30d
            })
    
    # Get user's saved place IDs to exclude them
    user_places_result = await db.execute(
        select(Place.google_place_id)
        .where(Place.user_id == current_user.id)
    )
    user_saved_place_ids = set(row[0] for row in user_places_result.all())
    
    # Check if there are places from other users
    other_users_places = [
        item for item in trending_data 
        if item["place"].user_id != current_user.id
    ]
    
    # If there are places from other users, exclude user's saved places
    # Otherwise, show user's own places (single-user case)
    if other_users_places:
        trending_data_filtered = [
            item for item in trending_data 
            if item["place"].google_place_id not in user_saved_place_ids
        ]
    else:
        trending_data_filtered = trending_data
    
    # Sort by score and take top 10
    trending_data_filtered.sort(key=lambda x: x["score"], reverse=True)
    top_trending = trending_data_filtered[:10]
    
    return [
        {
            "id": item["place"].id,
            "name": item["place"].name,
            "address": item["place"].address,
            "district": item["place"].district,
            "lat": item["place"].lat,
            "lng": item["place"].lng,
            "category": item["place"].category,
            "emoji": item["place"].emoji,
            "photo_url": item["place"].photo_url,
            "rating": item["place"].rating,
            "total_saves": item["saves_30d"],
            "recent_saves": item["saves_7d"],
            "trending_score": item["score"]
        }
        for item in top_trending
    ]


# ============================================================================
# Picked For You Endpoint (For Home Screen)
# ============================================================================

@app.get("/picked-for-you")
async def get_picked_for_you(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get AI-recommended places the user hasn't saved yet.
    Uses collaborative filtering based on what similar users have saved.
    """
    # Get all places the current user has saved
    user_places_result = await db.execute(
        select(Place.google_place_id)
        .where(Place.user_id == current_user.id)
    )
    user_saved_place_ids = set(row[0] for row in user_places_result.all())
    
    # Get all places from other users that current user hasn't saved
    all_places_result = await db.execute(
        select(Place)
        .where(Place.user_id != current_user.id)
        .order_by(desc(Place.created_at))
    )
    other_users_places = all_places_result.scalars().all()
    
    # If no other users exist, get user's own places
    if not other_users_places:
        user_places_result = await db.execute(
            select(Place)
            .where(Place.user_id == current_user.id)
            .order_by(desc(Place.created_at))
            .limit(10)
        )
        recommended_places = user_places_result.scalars().all()
    else:
        # Filter out places user has already saved
        recommended_places = []
        seen_google_ids = set()
        
        for place in other_users_places:
            if place.google_place_id not in user_saved_place_ids and place.google_place_id not in seen_google_ids:
                recommended_places.append(place)
                seen_google_ids.add(place.google_place_id)
                
                if len(recommended_places) >= 10:
                    break
    
    return [
        {
            "id": place.id,
            "name": place.name,
            "address": place.address,
            "district": place.district,
            "lat": place.lat,
            "lng": place.lng,
            "category": place.category,
            "emoji": place.emoji,
            "photo_url": place.photo_url,
            "rating": place.rating,
            "google_place_id": place.google_place_id
        }
        for place in recommended_places
    ]


# ============================================================================
# Support Local Endpoint (For Home Screen)
# ============================================================================

@app.get("/support-local")
async def get_support_local(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get independent/family-owned businesses.
    For MVP, return places tagged with 'local', 'independent', 'family-owned'.
    """
    result = await db.execute(
        select(Place)
        .order_by(desc(Place.created_at))
        .limit(50)
    )
    places = result.scalars().all()
    
    # Get user's saved place IDs to exclude them
    user_places_result = await db.execute(
        select(Place.google_place_id)
        .where(Place.user_id == current_user.id)
    )
    user_saved_place_ids = set(row[0] for row in user_places_result.all())
    
    # Check if there are places from other users
    other_users_places = [p for p in places if p.user_id != current_user.id]
    
    # Filter places with local-related tags
    local_places = []
    for place in places:
        # If there are other users, exclude user's saved places; otherwise include them
        if other_users_places:
            if place.google_place_id in user_saved_place_ids:
                continue
        
        if place.tags:
            tags_lower = [t.lower() for t in place.tags]
            if any(word in tags_lower for word in ['local', 'independent', 'family', 'small', 'neighborhood']):
                local_places.append(place)
    
    return [
        {
            "id": place.id,
            "name": place.name,
            "address": place.address,
            "district": place.district,
            "lat": place.lat,
            "lng": place.lng,
            "category": place.category,
            "emoji": place.emoji,
            "photo_url": place.photo_url,
            "rating": place.rating,
            "tags": place.tags
        }
        for place in local_places[:10]
    ]


# ============================================================================
# Friend Taste Match Endpoint (For Home Screen)
# ============================================================================

@app.get("/friend-taste-match")
async def get_friend_taste_match(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Calculate taste match percentage with friends.
    For MVP, return mock data with simplified format.
    """
    # TODO: Implement real friend matching logic
    # For now, return mock data
    return [
        {
            "friend_id": 1,
            "friend_name": "Sarah",
            "match_percentage": 87,
            "mutual_places": 12
        },
        {
            "friend_id": 2,
            "friend_name": "Mike",
            "match_percentage": 76,
            "mutual_places": 8
        },
        {
            "friend_id": 3,
            "friend_name": "Emma",
            "match_percentage": 65,
            "mutual_places": 5
        }
    ]


# ============================================================================
# AI Chat Endpoint (For ChatView)
# ============================================================================

class ChatRequest(BaseModel):
    message: str
    conversation_history: List[dict] = Field(default_factory=list)

@app.post("/chat")
async def chat(
    request: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    """
    AI chat endpoint for place recommendations and questions.
    Uses OpenAI to provide intelligent responses about Hong Kong places.
    """
    try:
        from openai import AzureOpenAI
        client = AzureOpenAI(
            api_key=os.getenv("AZURE_OPENAI_KEY"),
            api_version="2024-10-21",
            azure_endpoint="https://hkust.azure-api.net"
        )
        
        # Build messages for OpenAI
        messages = [
            {
                "role": "system",
                "content": (
                    "You are Radar's AI assistant helping users find cool spots in Hong Kong. "
                    "Your tone is casual, friendly, and Gen Z but not over the top - no excessive slang. "
                    "Use emojis sparingly (✨ ☕️ 🍝 🔥 occasionally). "
                    "When recommending places, respond with ONLY place names separated by | like this: "
                    "'Carbone Hong Kong|% Arabica|NOC Coffee' "
                    "If not recommending specific places, just give a helpful text response. "
                    "Keep responses under 100 words."
                )
            }
        ]
        
        # Add conversation history
        for msg in request.conversation_history[-10:]:  # Last 10 messages
            messages.append(msg)
        
        # Add current message
        messages.append({"role": "user", "content": request.message})
        
        # Call Azure OpenAI
        response = client.chat.completions.create(
            model="gpt-4o-mini",  # This is the Azure deployment name
            messages=messages,
            temperature=0.7,
            max_tokens=200
        )
        
        ai_response = response.choices[0].message.content
        
        logger.info(f"💬 Chat: {request.message[:50]}... → {ai_response[:50]}...")
        
        # Check if AI is recommending places (contains | separator)
        places_data = []
        if "|" in ai_response:
            # Extract place names
            place_names = [name.strip() for name in ai_response.split("|")]
            
            # Search for each place using Google Places
            from google_places_autocomplete import autocomplete_search
            for place_name in place_names[:5]:  # Max 5 places
                try:
                    results = await autocomplete_search(place_name, location="22.3193,114.1694")
                    if results:
                        # Take the first (best) result
                        places_data.append(results[0])
                except Exception as e:
                    logger.error(f"❌ Failed to search place '{place_name}': {e}")
                    continue
            
            # Create a friendly intro message
            intro_messages = [
                "here are some solid spots for you",
                "check these out",
                "here's what i found",
                "these places are pretty good"
            ]
            import random
            ai_response = random.choice(intro_messages)
        
        return {
            "response": ai_response,
            "places": places_data  # Array of place objects with photos, ratings, etc.
        }
        
    except Exception as e:
        logger.error(f"❌ Chat error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not process chat request"
        )


# ============================================================================
# ADMIN ENDPOINTS (Temporary)
# ============================================================================

@app.post("/admin/backfill")
async def run_backfill(db: AsyncSession = Depends(get_db)):
    """
    Temporary endpoint to run backfill script for opening hours.
    This will be removed after running once.
    """
    try:
        from google_places_helper import _get_place_details
        import json
        
        # Get all places
        result = await db.execute(select(Place))
        places = result.scalars().all()
        
        logger.info(f"📊 Found {len(places)} places to check")
        
        updated_count = 0
        failed_count = 0
        skipped_count = 0
        results = []
        
        for place in places:
            # Check if missing data
            needs_update = False
            
            if not place.opening_hours:
                logger.info(f"⚠️ {place.name} missing opening_hours")
                needs_update = True
            
            if not needs_update:
                logger.info(f"✅ {place.name} has complete data")
                skipped_count += 1
                continue
            
            # Fetch fresh data from Google
            if not place.google_place_id:
                logger.warning(f"⚠️ {place.name} has no google_place_id, skipping")
                failed_count += 1
                results.append({"place": place.name, "status": "failed", "reason": "no google_place_id"})
                continue
            
            logger.info(f"🔄 Fetching fresh data for {place.name}...")
            
            place_details = _get_place_details(place.google_place_id)
            
            if not place_details:
                logger.error(f"❌ Failed to fetch data for {place.name}")
                failed_count += 1
                results.append({"place": place.name, "status": "failed", "reason": "api error"})
                continue
            
            # Update opening hours
            if not place.opening_hours:
                opening_hours_data = place_details.get("opening_hours", {})
                if opening_hours_data:
                    weekday_text = opening_hours_data.get("weekday_text", [])
                    if weekday_text:
                        place.opening_hours = json.dumps(weekday_text)
                        logger.info(f"  ✅ Added opening_hours")
                        results.append({"place": place.name, "status": "updated", "added": "opening_hours"})
            
            updated_count += 1
        
        # Commit all changes
        await db.commit()
        
        summary = {
            "total": len(places),
            "updated": updated_count,
            "failed": failed_count,
            "skipped": skipped_count,
            "details": results
        }
        
        logger.info(f"\n🎉 Backfill complete!")
        logger.info(f"  ✅ Updated: {updated_count}")
        logger.info(f"  ❌ Failed: {failed_count}")
        logger.info(f"  ⏭️ Skipped: {skipped_count}")
        logger.info(f"  📊 Total: {len(places)}")
        
        return summary
        
    except Exception as e:
        logger.error(f"❌ Backfill error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Backfill failed: {str(e)}"
        )


# ============================================================================
# Run with: uvicorn main:app --reload
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
