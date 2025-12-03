"""
Radar Backend - Database Configuration
Async SQLAlchemy with PostgreSQL/SQLite fallback
"""

import os
import logging
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool

logger = logging.getLogger(__name__)

# Database URL
DATABASE_URL = os.getenv("DATABASE_URL")

# Handle Railway PostgreSQL URL format
if DATABASE_URL:
    if DATABASE_URL.startswith("postgresql://"):
        DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
    if DATABASE_URL.startswith("postgres://"):
        DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)

# Fallback to SQLite for development
if not DATABASE_URL:
    DATABASE_URL = "sqlite+aiosqlite:///./radar.db"
    logger.warning("⚠️ DATABASE_URL not set. Using SQLite: ./radar.db")
    logger.warning("⚠️ For production, add PostgreSQL in Railway!")
else:
    logger.info(f"✅ Using database: {DATABASE_URL[:30]}...")
    
print("DEBUG: FINAL DATABASE_URL =", DATABASE_URL)

# Create async engine
engine = create_async_engine(
    DATABASE_URL,
    echo=False,  # Set to True for SQL debugging
    poolclass=NullPool if "sqlite" in DATABASE_URL else None,
    pool_pre_ping=True if "postgresql" in DATABASE_URL else False,
)

# Create session maker
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)


async def get_db() -> AsyncSession:
    """Dependency for getting async database session"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Initialize database tables"""
    from models import Base
    
    async with engine.begin() as conn:
        # Create all tables
        await conn.run_sync(Base.metadata.create_all)
    
    logger.info("✅ Database tables created/verified")
