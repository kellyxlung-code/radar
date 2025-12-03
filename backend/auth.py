"""
Radar Backend - Authentication
Phone-only OTP with MVP bypass
"""

import os
import secrets
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from models import User
from database import get_db

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key-CHANGE-IN-PRODUCTION")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 30  # 30 days

# Security
security = HTTPBearer()

# MVP Mode - Accept any 6-digit code for testing
MVP_MODE = os.getenv("MVP_MODE", "true").lower() == "true"
MVP_BYPASS_CODE = "123456"


def generate_otp() -> str:
    """Generate 6-digit OTP"""
    return ''.join([str(secrets.randbelow(10)) for _ in range(6)])


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create JWT access token"""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    
    return encoded_jwt


async def get_user_by_phone(db: AsyncSession, phone_number: str) -> Optional[User]:
    """Get user by phone number"""
    result = await db.execute(
        select(User).where(User.phone_number == phone_number)
    )
    return result.scalar_one_or_none()


async def create_user(db: AsyncSession, phone_number: str) -> User:
    """Create new user"""
    user = User(phone_number=phone_number)
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def send_otp(phone_number: str, db: AsyncSession) -> dict:
    """
    Send OTP to phone number
    MVP: Just generate and store, don't actually send SMS
    """
    # Generate OTP
    otp_code = generate_otp()
    otp_expires_at = datetime.utcnow() + timedelta(minutes=5)
    
    # Find or create user
    user = await get_user_by_phone(db, phone_number)
    if not user:
        user = await create_user(db, phone_number)
    
    # Store OTP
    user.otp_code = otp_code
    user.otp_expires_at = otp_expires_at
    await db.commit()
    
    # MVP: Return OTP in response for testing
    if MVP_MODE:
        return {
            "message": "OTP sent (MVP mode)",
            "mock_otp": otp_code,
            "expires_in_minutes": 5
        }
    
    # Production: Actually send SMS here
    # TODO: Integrate with Twilio/AWS SNS
    return {
        "message": "OTP sent to your phone",
        "expires_in_minutes": 5
    }


async def verify_otp(phone_number: str, otp_code: str, db: AsyncSession) -> dict:
    """
    Verify OTP and return JWT token
    MVP: Accept "123456" as bypass code
    """
    # Get user
    user = await get_user_by_phone(db, phone_number)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found. Please request OTP first."
        )
    
    # MVP bypass
    if MVP_MODE and otp_code == MVP_BYPASS_CODE:
        # Generate token
        access_token = create_access_token(data={"sub": user.phone_number})
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "user_id": user.id,
            "mvp_bypass": True
        }
    
    # Check OTP
    if not user.otp_code:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No OTP found. Please request OTP first."
        )
    
    # Check expiry
    if user.otp_expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP expired. Please request a new one."
        )
    
    # Verify OTP
    if user.otp_code != otp_code:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid OTP code."
        )
    
    # Clear OTP after successful verification
    user.otp_code = None
    user.otp_expires_at = None
    await db.commit()
    
    # Generate token
    access_token = create_access_token(data={"sub": user.phone_number})
    
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.id
    }


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get current authenticated user from JWT token"""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        phone_number: str = payload.get("sub")
        
        if phone_number is None:
            raise credentials_exception
            
    except JWTError:
        raise credentials_exception
    
    user = await get_user_by_phone(db, phone_number)
    if user is None:
        raise credentials_exception
    
    return user


async def get_current_user_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> Optional[User]:
    """Get current user if authenticated, None otherwise"""
    if not credentials:
        return None
    
    try:
        return await get_current_user(credentials, db)
    except HTTPException:
        return None
