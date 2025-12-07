"""
Radar Backend - Database Models
Optimized for MVP with emoji categories
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Boolean, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base
from datetime import datetime

Base = declarative_base()


class User(Base):
    """User model - phone-only authentication"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String, unique=True, index=True, nullable=False)
    
    # OTP fields
    otp_code = Column(String, nullable=True)
    otp_expires_at = Column(DateTime, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    places = relationship("Place", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User {self.phone_number}>"


class Place(Base):
    """Place model - venues pinned by users"""
    __tablename__ = "places"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    # Basic info
    name = Column(String, nullable=False, index=True)
    address = Column(String)
    district = Column(String, index=True)  # Central, TST, Wan Chai, etc.
    
    # Location
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    
    # Google Places data
    google_place_id = Column(String, unique=True, index=True)
    photo_url = Column(String)
    rating = Column(Float)
    price_level = Column(Integer)  # 1-4
    opening_hours = Column(JSON)  # Store as JSON
    phone = Column(String)
    website = Column(String)
    
    # Category & Emoji (Corner-style)
    category = Column(String, index=True)  # eat, cafes, bars, shops, leisure, go_out
    emoji = Column(String, default="📍")  # Default pin emoji
    
    # Social source
    source_platform = Column(String)  # instagram, xiaohongshu
    source_url = Column(String)
    source_caption = Column(Text)
    
    # User state
    is_visited = Column(Boolean, default=False)
    is_favorite = Column(Boolean, default=False)
    user_notes = Column(Text)
    
    # AI extracted tags
    tags = Column(JSON)  # ["aesthetic", "minimal", "brunch"]
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow, index=True)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="places")
    
    def __repr__(self):
        return f"<Place {self.name} ({self.emoji})>"


# Category to Emoji mapping (Corner-style)
CATEGORY_EMOJIS = {
    "eat": "🍜",           # Restaurants
    "cafes": "☕",         # Cafes
    "bars": "🍸",          # Bars & nightlife
    "shops": "🛍️",        # Shopping
    "leisure": "🎭",       # Entertainment, activities
    "go_out": "✨",        # Events, experiences
    "nature": "🌳",        # Parks, hiking
    "culture": "🎨",       # Museums, galleries
    "fitness": "💪",       # Gyms, sports
    "beauty": "💅",        # Salons, spas
    "default": "📍"        # Fallback
}


def get_emoji_for_category(category: str) -> str:
    """Get emoji for a category"""
    return CATEGORY_EMOJIS.get(category.lower(), CATEGORY_EMOJIS["default"])


def get_category_from_tags(tags: list) -> str:
    """
    Determine category from AI-extracted tags
    Similar to how Corner categorizes places
    """
    tags_lower = [t.lower() for t in tags]
    
    # Cafes
    if any(word in tags_lower for word in ["cafe", "coffee", "espresso", "latte", "cappuccino"]):
        return "cafes"
    
    # Bars
    if any(word in tags_lower for word in ["bar", "cocktail", "wine", "beer", "pub", "nightlife"]):
        return "bars"
    
    # Restaurants
    if any(word in tags_lower for word in ["restaurant", "dining", "food", "cuisine", "noodles", "dim sum"]):
        return "eat"
    
    # Shops
    if any(word in tags_lower for word in ["shop", "store", "boutique", "retail", "shopping"]):
        return "shops"
    
    # Leisure
    if any(word in tags_lower for word in ["cinema", "theater", "entertainment", "activity", "fun"]):
        return "leisure"
    
    # Go out
    if any(word in tags_lower for word in ["event", "party", "club", "experience", "rooftop"]):
        return "go_out"
    
    # Nature
    if any(word in tags_lower for word in ["park", "nature", "hiking", "beach", "outdoor"]):
        return "nature"
    
    # Culture
    if any(word in tags_lower for word in ["museum", "gallery", "art", "culture", "exhibition"]):
        return "culture"
    
    # Default to eat (most common)
    return "eat"


class Event(Base):
    """Event model - happenings in Hong Kong"""
    __tablename__ = "events"
    
    id = Column(Integer, primary_key=True, index=True)
    
    # Basic info
    name = Column(String, nullable=False)
    description = Column(Text)
    photo_url = Column(String)
    
    # Location
    location = Column(String)
    district = Column(String, index=True)
    lat = Column(Float)
    lng = Column(Float)
    
    # Dates
    start_date = Column(DateTime, nullable=False, index=True)
    end_date = Column(DateTime, nullable=False, index=True)
    
    # Category
    category = Column(String, index=True)  # art, music, food, nightlife, culture, market
    
    # External link
    url = Column(String)
    
    # Status
    is_active = Column(Boolean, default=True, index=True)
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f"<Event {self.name}>"
