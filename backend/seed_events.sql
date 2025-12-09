-- Seed Hong Kong Events for Radar App
-- Copy and paste this into Railway's PostgreSQL database console

INSERT INTO events (name, description, photo_url, location, district, start_date, end_date, category, url, time_description, created_at, updated_at)
VALUES 
(
    'PMQ Night Market',
    'Creative market with local designers, handmade crafts, and food stalls',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
    'PMQ',
    'Central',
    NOW(),
    NOW() + INTERVAL '7 days',
    'market',
    'https://pmq.org.hk',
    'Tonight',
    NOW(),
    NOW()
),
(
    'Temple Street Night Market',
    'Famous night market with fortune tellers, street food, and souvenirs',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800',
    'Temple Street',
    'Yau Ma Tei',
    NOW(),
    NOW() + INTERVAL '365 days',
    'market',
    'https://www.discoverhongkong.com',
    'Tonight',
    NOW(),
    NOW()
),
(
    'Tai Kwun Night Market',
    'Heritage site with art exhibitions, performances, and dining',
    'https://images.unsplash.com/photo-1536924940846-227afb31e2a5?w=800',
    'Tai Kwun',
    'Central',
    NOW(),
    NOW() + INTERVAL '30 days',
    'culture',
    'https://www.taikwun.hk',
    'Tonight',
    NOW(),
    NOW()
),
(
    'Clockenflap Music Festival',
    'Hong Kong''s biggest outdoor music and arts festival',
    'https://images.unsplash.com/photo-1459749411175-04bf5292ceea?w=800',
    'Central Harbourfront',
    'Central',
    NOW() + INTERVAL '3 days',
    NOW() + INTERVAL '5 days',
    'music',
    'https://www.clockenflap.com',
    'This Weekend',
    NOW(),
    NOW()
),
(
    'Hong Kong Wine & Dine Festival',
    'Annual food and wine festival at the harbourfront',
    'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=800',
    'Central Harbourfront',
    'Central',
    NOW() + INTERVAL '14 days',
    NOW() + INTERVAL '18 days',
    'food',
    'https://www.discoverhongkong.com',
    'Next Week',
    NOW(),
    NOW()
);
