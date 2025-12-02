from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timedelta
import random
import os
import jwt
from jwt.exceptions import InvalidTokenError

from database import SessionLocal
from models import User

router = APIRouter(
    prefix="/auth",
    tags=["Authentication", "OTP Flow"],
)

# JWT configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-super-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 365 * 50  # long lived

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
OTP_EXPIRY_MINUTES = 5

# -------------------------
# Schemas
# -------------------------

class PhoneNumberRequest(BaseModel):
    phone_number: str

class VerifyOTPRequest(PhoneNumberRequest):
    otp_code: str
    # ❌ password removed
    # password: str  

class Token(BaseModel):
    access_token: str
    token_type: str

class UserSchema(BaseModel):
    id: int
    phone_number: str

    class Config:
        from_attributes = True

# -------------------------
# DB Dependency
# -------------------------

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# -------------------------
# Utils
# -------------------------

def get_user_by_phone_number(db: Session, phone_number: str) -> Optional[User]:
    return db.query(User).filter(User.phone_number == phone_number).first()

# -------------------------
# JWT helpers
# -------------------------

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.now() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))

    to_encode.update(
        {
            "exp": int(expire.timestamp()),
            "user_id": data["user_id"],
            "sub": str(data["user_id"]),
        }
    )

    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_access_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except InvalidTokenError:
        return None

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    payload = decode_access_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = db.query(User).filter(User.id == payload.get("user_id")).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid token")

    return user

# -------------------------
# OTP ENDPOINTS
# -------------------------

@router.post("/send-otp", status_code=status.HTTP_200_OK)
def send_otp(req: PhoneNumberRequest, db: Session = Depends(get_db)):
    phone_number = req.phone_number
    otp_code = "".join([str(random.randint(0, 9)) for _ in range(6)])
    otp_expires_at = datetime.now() + timedelta(minutes=OTP_EXPIRY_MINUTES)

    user = get_user_by_phone_number(db, phone_number)
    if not user:
        user = User(
            phone_number=phone_number,
            otp_code=otp_code,
            otp_expires_at=otp_expires_at,
        )
        db.add(user)
        db.commit()
    else:
        user.otp_code = otp_code
        user.otp_expires_at = otp_expires_at
        db.commit()

    print(f"📲 MOCK SMS → OTP for {phone_number}: {otp_code}")

    return {"message": "OTP sent", "mock_otp": otp_code}

@router.post("/verify-otp", response_model=Token)
def verify_otp_and_login(req: VerifyOTPRequest, db: Session = Depends(get_db)):

    user = get_user_by_phone_number(db, req.phone_number)
    if not user:
        raise HTTPException(404, "User not found. Request OTP first.")

    if user.otp_code != req.otp_code or (
        user.otp_expires_at and user.otp_expires_at < datetime.now()
    ):
        raise HTTPException(401, "Invalid or expired OTP.")

    # Clear OTP
    user.otp_code = None
    user.otp_expires_at = None

    # ❌ Remove password storage
    # user.hashed_password = hash_password(req.password)

    db.commit()
    db.refresh(user)

    # Issue JWT
    access_token = create_access_token(data={"user_id": user.id})

    return {"access_token": access_token, "token_type": "bearer"}

# -------------------------
# ❌ PASSWORD LOGIN ENDPOINT REMOVED
# -------------------------

# @router.post("/token")  <-- You no longer need this
# def login_for_access_token(...):
#     pass  # Removed for OTP-only auth

# -------------------------
# Current User
# -------------------------

@router.get("/users/me", response_model=UserSchema)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user
