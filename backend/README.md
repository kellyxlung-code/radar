# Radar Backend

FastAPI backend for Radar - a location-based social app for discovering and sharing places in Hong Kong.

## Features

- 🔐 OTP Authentication (SMS-based login)
- 📍 Instagram Import (extract places from Instagram posts)
- 🗺️ Google Places Integration (autocomplete, details, photos)
- 💬 AI Chat (powered by OpenAI)
- 🏷️ Smart Categorization (emoji-based categories)
- 📊 PostgreSQL Database

## Tech Stack

- **Framework**: FastAPI
- **Database**: PostgreSQL (async with SQLAlchemy)
- **AI**: OpenAI GPT-4.1-mini
- **External APIs**: Google Places API, Microlink API

## Environment Variables

Required environment variables:

```bash
DATABASE_URL=postgresql+asyncpg://user:password@host:port/database
OPENAI_API_KEY=your_openai_api_key
GOOGLE_PLACES_KEY=your_google_places_api_key
JWT_SECRET=your_jwt_secret
```

## Local Development

```bash
# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn main:app --reload --port 8000
```

## Deployment

Deployed on Railway with automatic deployments from GitHub.

## API Endpoints

### Authentication
- `POST /auth/send-otp` - Send OTP to phone number
- `POST /auth/verify-otp` - Verify OTP and get JWT token

### Places
- `GET /places` - Get all places for current user
- `POST /places` - Create a new place
- `POST /import-url` - Import place from Instagram URL

### Search
- `GET /search` - Autocomplete search for places
- `GET /place-details/{place_id}` - Get Google Place details

### Chat
- `POST /chat` - AI chat for place recommendations

## License

Private - All rights reserved
