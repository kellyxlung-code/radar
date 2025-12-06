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
from sqlalchemy import select, and_

# Local imports
from database import init_db, get_db
from models import User, Place, get_emoji_for_category, get_category_from_tags
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
    is_visited: bool
    is_favorite: bool
    tags: Optional[List[str]]
    source_url: Optional[str]
    created_at: str
    
    class Config:
        from_attributes = True


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
    
    # Step 4: Save to database
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
        source_platform=ai_data.get("source_platform"),
        source_url=url,
        source_caption=ai_data.get("source_caption"),
        tags=tags,
    )
    
    db.add(place)
    await db.commit()
    await db.refresh(place)
    
    logger.info(f"✅ Saved place: {place.name} ({place.emoji})")
    
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
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=place.source_url,
        created_at=place.created_at.isoformat(),
    )


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
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=place.source_url,
        created_at=place.created_at.isoformat(),
    )


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
    
    return [
        PlaceResponse(
            id=p.id,
            name=p.name,
            address=p.address,
            district=p.district,
            lat=p.lat,
            lng=p.lng,
            category=p.category,
            emoji=p.emoji,
            photo_url=p.photo_url,
            rating=p.rating,
            is_visited=p.is_visited,
            is_favorite=p.is_favorite,
            tags=p.tags,
            source_url=p.source_url,
            created_at=p.created_at.isoformat(),
        )
        for p in places
    ]


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
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=place.source_url,
        created_at=place.created_at.isoformat(),
    )


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
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=place.source_url,
        created_at=place.created_at.isoformat(),
    )


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


@app.post("/add-place-by-id")
async def add_place_by_id(
    place_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Add a place by Google Place ID (from autocomplete).
    Returns full place data.
    """
    # Get place details from Google
    google_data = await get_place_details(place_id)
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
        google_place_id=place_id,
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
        is_visited=place.is_visited,
        is_favorite=place.is_favorite,
        tags=place.tags,
        source_url=None,
        created_at=place.created_at.isoformat(),
    )


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
        from openai import OpenAI
        client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
        
        # Build messages for OpenAI
        messages = [
            {
                "role": "system",
                "content": (
                    "You are Radar's AI assistant, an expert on Hong Kong restaurants, cafes, bars, and venues. "
                    "You help users discover amazing places to eat, drink, and hang out in Hong Kong. "
                    "Be friendly, concise, and enthusiastic. "
                    "\n\nIMPORTANT LOCATION CONTEXT:\n"
                    "- HKUST = Hong Kong University of Science and Technology in Clear Water Bay (Sai Kung District)\n"
                    "- HKU = University of Hong Kong in Pok Fu Lam (Western District)\n"
                    "- CUHK = Chinese University of Hong Kong in Sha Tin (New Territories)\n"
                    "- When users mention universities or specific areas, recommend places NEAR that location, not across the city.\n"
                    "- Pay close attention to the specific location/district mentioned in the query.\n"
                    "- If a user asks for places at/near HKUST, recommend places in Clear Water Bay, Sai Kung, or nearby areas.\n"
                    "- If a user asks for Central, recommend Central places, not Tsim Sha Tsui.\n"
                    "\nIf asked about places, provide specific recommendations with exact district names. "
                    "Keep responses under 150 words."
                )
            }
        ]
        
        # Add conversation history
        for msg in request.conversation_history[-10:]:  # Last 10 messages
            messages.append(msg)
        
        # Add current message
        messages.append({"role": "user", "content": request.message})
        
        # Call OpenAI
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            temperature=0.7,
            max_tokens=200
        )
        
        ai_response = response.choices[0].message.content
        
        logger.info(f"💬 Chat: {request.message[:50]}... → {ai_response[:50]}...")
        
        return {"response": ai_response}
        
    except Exception as e:
        logger.error(f"❌ Chat error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not process chat request"
        )


# ============================================================================
# Run with: uvicorn main:app --reload
# ============================================================================

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=True)
