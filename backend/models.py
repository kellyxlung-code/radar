# backend/models.py

from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    Boolean,
    Text,
    ForeignKey,
    DateTime,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from database import Base  # use shared Base


class User(Base):
    """
    User identified by phone number with OTP-only login.
    """
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(50), unique=True, index=True, nullable=False)

    # ❌ REMOVED: password — No longer needed for OTP-only
    # hashed_password = Column(String(128), nullable=True)

    # OTP fields
    otp_code = Column(String(6), nullable=True, comment="Temporary 6-digit OTP code")
    otp_expires_at = Column(
        DateTime, nullable=True, comment="Timestamp for OTP expiry"
    )

    # Relationship to places
    places = relationship("Place", back_populates="owner")

    def __repr__(self):
        return ""


class Place(Base):
    """
    Unified place model:
    - social source (caption, author, source_url, post_image/video)
    - venue info (lat,lng,address,category,photos,rating)
    - user state (owner, is_pinned, notes, confidence)
    """
    __tablename__ = "places"

    # Core identity
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)

    # Social source
    source_url = Column(Text, nullable=True)
    source_type = Column(String(50), nullable=True)  # 'instagram', 'red', 'tiktok'
    caption = Column(Text, nullable=True)
    author = Column(String(100), nullable=True)
    post_image_url = Column(Text, nullable=True)
    post_video_url = Column(Text, nullable=True)
    imported_at = Column(DateTime, server_default=func.now(), nullable=False)

    # Venue location data (Google Places)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    district = Column(String(255), nullable=True)
    address = Column(Text, nullable=True)
    place_id = Column(String(255), nullable=True, index=True)

    # Venue details
    category = Column(String(255), nullable=True)
    category_emoji = Column(String(10), nullable=True)
    photo_url = Column(Text, nullable=True)  # main venue photo

    # For now, store opening_hours as JSON-encoded text (can change to JSONB later)
    opening_hours = Column(Text, nullable=True)
    is_open_now = Column(Boolean, nullable=True)
    rating = Column(Float, nullable=True)
    user_ratings_total = Column(Integer, nullable=True)

    # User relationship
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="places")
    is_pinned = Column(
        Boolean,
        default=False,
        nullable=False,
        comment="True if the user has confirmed this place (pinned)",
    )

    # AI confidence / method
    confidence = Column(Float, nullable=True)
    extraction_method = Column(String(50), nullable=True)  # 'caption', 'vision', 'manual'

    # User refinement
    notes = Column(Text, nullable=True, comment="Personal notes added by the user")

    def __repr__(self):
        return ""
