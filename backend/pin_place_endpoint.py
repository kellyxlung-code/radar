from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.orm import Session

from database import get_db
from models import Place, User
from auth import get_current_user
from google_places_helper import fetch_place_details_from_google
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# ============================================================================
# REQUEST/RESPONSE MODELS
# ============================================================================

class PlaceCandidateRequest(BaseModel):
    """
    Lightweight place info sent from client.
    Radar will enrich this with Google Places data.
    """
    # Minimum required for Google search
    name: str                       # e.g. "Bar Leone"
    district: Optional[str] = None  # e.g. "Central"
    city: Optional[str] = "Hong Kong"

    # Optional hints
    category_hint: Optional[str] = None
    lat: Optional[float] = None
    lng: Optional[float] = None

    # User context (from Instagram/RED post)
    caption: Optional[str] = None
    author: Optional[str] = None
    source_type: Optional[str] = None
    source_url: Optional[str] = None
    image: Optional[str] = None

    # User customization
    notes: Optional[str] = None
    custom_emoji: Optional[str] = None


class PlaceResponse(BaseModel):
    """
    Response after successfully pinning a place.
    """
    id: int
    name: str
    lat: float
    lng: float
    address: Optional[str]
    district: Optional[str]
    category: Optional[str]
    category_emoji: Optional[str]
    photo_url: Optional[str]
    rating: Optional[float]
    is_open_now: Optional[int]
    message: str


# ============================================================================
# SINGLE PIN ENDPOINT
# ============================================================================

@router.post("/pin-place", response_model=PlaceResponse)
async def pin_place(
    candidate: PlaceCandidateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Pin a place to the user's map.

    Flow:
    1. Client sends lightweight candidate info (name + district)
    2. Backend fetches canonical data from Google Places
    3. Merges Google data with user context (caption, source, etc.)
    4. Saves enriched place to database
    5. Returns full place data to client
    """
    logger.info(f"📍 Pinning place: {candidate.name} for user {current_user.id}")

    # Step 1: Fetch canonical data from Google
    candidate_dict = candidate.dict()
    google_data = fetch_place_details_from_google(candidate_dict)

    if not google_data:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Could not find '{candidate.name}' on Google Places. "
                "Please check the name and try again, or add more details like district."
            ),
        )

    # Extra safety: validate that required fields exist
    for key in ["lat", "lng", "place_id", "name"]:
        if key not in google_data:
            logger.error(f"Google data missing required field '{key}': {google_data}")
            raise HTTPException(
                status_code=500,
                detail=f"Internal error: missing '{key}' from Google data for {candidate.name}",
            )

    # Step 2: Check if place already exists for this user
    existing_place = (
        db.query(Place)
        .filter(
            Place.owner_id == current_user.id,
            Place.place_id == google_data["place_id"],
        )
        .first()
    )

    if existing_place:
        logger.info(f"⚠️ Place already pinned: {google_data['name']}")
        return PlaceResponse(
            id=existing_place.id,
            name=existing_place.name,
            lat=existing_place.lat,
            lng=existing_place.lng,
            address=existing_place.address,
            district=existing_place.district,
            category=existing_place.category,
            category_emoji=existing_place.category_emoji,
            photo_url=existing_place.photo_url,
            rating=existing_place.rating,
            is_open_now=existing_place.is_open_now,
            message="This place is already pinned to your map!",
        )

    # Step 3: Create new place with enriched data
    new_place = Place(
        # Google canonical data
        place_id=google_data["place_id"],
        name=google_data["name"],
        lat=google_data["lat"],
        lng=google_data["lng"],
        address=google_data.get("address"),
        district=google_data.get("district"),
        category=google_data.get("category"),
        category_emoji=candidate.custom_emoji or google_data.get("category_emoji", "📍"),
        opening_hours=google_data.get("opening_hours"),
        is_open_now=google_data.get("is_open_now"),
        rating=google_data.get("rating"),
        user_ratings_total=google_data.get("user_ratings_total"),
        photo_url=google_data.get("photo_url"),

        # User context
        caption=candidate.caption,
        author=candidate.author,
        source_type=candidate.source_type,
        source_url=candidate.source_url,
        image=candidate.image,

        # User customization
        notes=candidate.notes,

        # Ownership
        owner_id=current_user.id,

        # Default to pinned
        is_pinned=True,
    )

    db.add(new_place)
    db.commit()
    db.refresh(new_place)

    logger.info(f"✅ Pinned place: {new_place.name} (ID: {new_place.id})")

    return PlaceResponse(
        id=new_place.id,
        name=new_place.name,
        lat=new_place.lat,
        lng=new_place.lng,
        address=new_place.address,
        district=new_place.district,
        category=new_place.category,
        category_emoji=new_place.category_emoji,
        photo_url=new_place.photo_url,
        rating=new_place.rating,
        is_open_now=new_place.is_open_now,
        message=f"Successfully pinned {new_place.name} to your map!",
    )


# ============================================================================
# BULK PIN ENDPOINT (for seeding/import)
# ============================================================================

class BulkPinRequest(BaseModel):
    candidates: List[PlaceCandidateRequest]


class BulkPinResponse(BaseModel):
    success_count: int
    failed_count: int
    places: List[PlaceResponse]
    errors: List[str]


@router.post("/pin-places-bulk", response_model=BulkPinResponse)
async def pin_places_bulk(
    request: BulkPinRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Pin multiple places at once.
    Useful for:
    - Seeding test data
    - Importing from Instagram/RED in batch
    - Migrating from other apps
    """
    logger.info(
        f"📍 Bulk pinning {len(request.candidates)} places for user {current_user.id}"
    )

    success_count = 0
    failed_count = 0
    places: List[PlaceResponse] = []
    errors: List[str] = []

    for candidate in request.candidates:
        try:
            result = await pin_place(candidate, db, current_user)
            places.append(result)
            success_count += 1
        except Exception as e:
            failed_count += 1
            error_msg = f"{candidate.name}: {str(e)}"
            errors.append(error_msg)
            logger.error(f"❌ Failed to pin {candidate.name}: {e}")

    return BulkPinResponse(
        success_count=success_count,
        failed_count=failed_count,
        places=places,
        errors=errors,
    )

