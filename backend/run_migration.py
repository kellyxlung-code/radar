"""
Run database migrations
"""
import asyncio
from database import engine
from sqlalchemy import text

async def run_migration():
    """Run the events table migration"""
    
    # Read migration SQL
    with open('migrations/add_events_table.sql', 'r') as f:
        sql = f.read()
    
    # Split by semicolon and execute each statement
    statements = [s.strip() for s in sql.split(';') if s.strip()]
    
    async with engine.begin() as conn:
        for statement in statements:
            if statement:
                print(f"Executing: {statement[:100]}...")
                try:
                    await conn.execute(text(statement))
                    print("✓ Success")
                except Exception as e:
                    print(f"✗ Error: {e}")
    
    print("\n✅ Migration complete!")

if __name__ == "__main__":
    asyncio.run(run_migration())
