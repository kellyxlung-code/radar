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
else:
    DATABASE_URL = "sqlite+aiosqlite:///./radar.db"
    logger.warning("⚠️ DATABASE_URL not set. Using SQLite: ./radar.db")
    logger.warning("⚠️ For production, add PostgreSQL in Railway!")

print("DEBUG: FINAL DATABASE_URL =", DATABASE_URL)

# Create async engine
engine = create_async_engine(
    DATABASE_URL,
    echo=False,
    poolclass=NullPool if "sqlite" in DATABASE_URL else None,
    pool_pre_ping=True if "postgresql" in DATABASE_URL else False,
)

# Async session maker
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)

async def get_db() -> AsyncSession:
    """Dependency: get async DB session"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

# -----------------------------------------------------
#  SAFE INIT (NO GREENLET) — SQLAlchemy async-compatible
# -----------------------------------------------------

async def init_db():
    """Create tables without greenlet (compatible with Python 3.13)"""
    from models import Base

    async with engine.begin() as conn:

        # Run table creation in sync mode safely without requiring greenlet
        def create_all(sync_conn):
            Base.metadata.create_all(sync_conn)

        await conn.run_sync(create_all)

    logger.info("✅ Database tables created/verified")
