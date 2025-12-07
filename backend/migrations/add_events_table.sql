-- Migration: Add events table for "Happening Now in HK" section
-- Date: 2024-12-07

CREATE TABLE IF NOT EXISTS events (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    photo_url VARCHAR(500),
    location VARCHAR(255),
    district VARCHAR(100),
    lat DECIMAL(10, 8),
    lng DECIMAL(11, 8),
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    category VARCHAR(100),  -- art, music, food, nightlife, culture, market
    url VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Index for fast queries
CREATE INDEX IF NOT EXISTS idx_events_dates ON events(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active);

-- Sample events for Hong Kong
INSERT INTO events (name, description, photo_url, location, district, lat, lng, start_date, end_date, category, url) VALUES
('PMQ Night Market', 'Creative market with local designers and food stalls', 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800', 'PMQ', 'Central', 22.2842, 114.1533, NOW(), NOW() + INTERVAL '7 days', 'market', 'https://pmq.org.hk'),
('Art Basel Hong Kong 2024', 'Asia''s premier international art fair', 'https://images.unsplash.com/photo-1536924940846-227afb31e2a5?w=800', 'Hong Kong Convention Centre', 'Wan Chai', 22.2819, 114.1748, '2024-03-26', '2024-03-30', 'art', 'https://artbasel.com/hong-kong'),
('Tai Hang Fire Dragon Dance', 'Traditional Mid-Autumn Festival celebration', 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800', 'Tai Hang', 'Causeway Bay', 22.2793, 114.1903, '2024-09-15', '2024-09-17', 'culture', 'https://www.discoverhongkong.com'),
('Temple Street Night Market', 'Famous night market with fortune tellers and street food', 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800', 'Temple Street', 'Yau Ma Tei', 22.3092, 114.1713, NOW(), NOW() + INTERVAL '365 days', 'market', 'https://www.discoverhongkong.com');
