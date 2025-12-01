from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from sqlalchemy.orm import Session
from passlib.context import CryptContext
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
# Very long-lived tokens for “never sign out” UX
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 365 * 50

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
OTP_EXPIRY_MINUTES = 5

# ----- Schemas -----


class PhoneNumberRequest(BaseModel):
    phone_number: str


class VerifyOTPRequest(PhoneNumberRequest):
    otp_code: str
    password: str  # set password during verification


class Token(BaseModel):
    access_token: str
    token_type: str


class UserSchema(BaseModel):
    id: int
    phone_number: str

    class Config:
        from_attributes = True


# ----- DB dependency -----


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ----- Utils -----


def hash_password(password: str) -> str:
    # TEMP: bypass bcrypt for demo to avoid environment issues
    # NOTE: This is NOT secure for production.
    return password


def verify_password(plain_password: str, hashed_password: str) -> bool:
    # With dummy hashing, just compare directly.
    return plain_password == hashed_password


def get_user_by_phone_number(db: Session, phone_number: str) -> Optional[User]:
    return db.query(User).filter(User.phone_number == phone_number).first()


# ----- JWT helpers -----


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now() + expires_delta
    else:
        expire = datetime.now() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    # store both user_id and sub as the same value
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
    except InvalidTokenError as e:
        print(f"JWT Decode Error: {e}")
        return None


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    payload = decode_access_token(token)
    if payload is None:
        raise credentials_exception

    user_id = payload.get("user_id")
    if user_id is None:
        raise credentials_exception

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise credentials_exception

    return user


# ----- OTP endpoints -----


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

    print(
        f"MOCK SMS: OTP for {phone_number} is {otp_code}. "
        f"Expires at {otp_expires_at.strftime('%H:%M:%S')}"
    )

    return {"message": f"OTP sent successfully to {phone_number}", "mock_otp": otp_code}


@router.post("/verify-otp", response_model=Token)
def verify_otp_and_login(req: VerifyOTPRequest, db: Session = Depends(get_db)):
    user = get_user_by_phone_number(db, req.phone_number)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found. Please request OTP first.",
        )

    if user.otp_code != req.otp_code or (
        user.otp_expires_at and user.otp_expires_at < datetime.now()
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP.",
        )

    user.otp_code = None
    user.otp_expires_at = None

    # DEBUG: log incoming password length and preview
    print(
        f"[DEBUG verify-otp] password len={len(req.password)}, "
        f"preview={str(req.password)[:50]}"
    )

    user.hashed_password = hash_password(req.password)
    db.commit()
    db.refresh(user)

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"user_id": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/token", response_model=Token)
async def login_for_access_token(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    phone_number = form_data.username
    user = get_user_by_phone_number(db, phone_number)

    if not user or not user.hashed_password or not verify_password(
        form_data.password, user.hashed_password
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect phone number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"user_id": user.id}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}


@router.get("/users/me", response_model=UserSchema)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user

