"""
Chat Service - AI-powered chat for place recommendations
Uses OpenAI to provide personalized place suggestions
"""

import os
from openai import OpenAI
from typing import List, Dict

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

async def get_chat_response(
    message: str,
    user_places: List[Dict],
    conversation_history: List[Dict] = None
) -> str:
    """
    Get AI chat response with context about user's saved places
    
    Args:
        message: User's chat message
        user_places: List of user's saved places for context
        conversation_history: Previous messages in conversation
    
    Returns:
        AI response string
    """
    
    # Build context about user's places
    places_context = ""
    if user_places:
        places_context = "\n\nUser's saved places:\n"
        for place in user_places[:10]:  # Limit to 10 for token efficiency
            emoji = place.get('emoji', '📍')
            name = place.get('name', 'Unknown')
            category = place.get('category', 'place')
            places_context += f"- {emoji} {name} ({category})\n"
    
    # System prompt
    system_prompt = f"""You are Radar's AI assistant, helping users discover amazing places in Hong Kong.

You are friendly, enthusiastic, and knowledgeable about Hong Kong's food, cafe, bar, and nightlife scene.

Key personality traits:
- Gen Z friendly and casual (but not cringe)
- Use emojis naturally (not excessively)
- Give specific recommendations with details
- Reference user's saved places when relevant
- Keep responses concise (2-3 sentences max unless asked for more)

When recommending places:
- Mention the vibe, what they're known for
- Include the area/district
- Suggest similar places if relevant
{places_context}"""

    # Build messages array
    messages = [{"role": "system", "content": system_prompt}]
    
    # Add conversation history if provided
    if conversation_history:
        messages.extend(conversation_history[-6:])  # Last 6 messages for context
    
    # Add current message
    messages.append({"role": "user", "content": message})
    
    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=messages,
            max_tokens=300,
            temperature=0.8,
        )
        
        return response.choices[0].message.content
        
    except Exception as e:
        print(f"❌ Chat error: {e}")
        return "Sorry, I'm having trouble connecting right now. Try again in a moment! 🙏"


async def get_place_recommendations(
    query: str,
    user_location: Dict = None,
    user_places: List[Dict] = None
) -> List[Dict]:
    """
    Get structured place recommendations based on query
    
    Args:
        query: User's search query (e.g., "best brunch spots")
        user_location: User's current location {"lat": float, "lng": float}
        user_places: User's saved places for personalization
    
    Returns:
        List of recommended places with details
    """
    
    # Build context
    context = f"User query: {query}\n"
    
    if user_location:
        context += f"User location: {user_location.get('lat')}, {user_location.get('lng')}\n"
    
    if user_places:
        context += f"User has saved {len(user_places)} places\n"
    
    system_prompt = """You are a Hong Kong place recommendation expert.
    
Given a user query, suggest 3-5 specific places in Hong Kong.

Return ONLY a JSON array with this exact structure:
[
  {
    "name": "Place Name",
    "category": "cafe|restaurant|bar|nightlife|dessert|shopping|activity|attraction",
    "emoji": "appropriate emoji",
    "description": "One sentence about what makes it special",
    "district": "Hong Kong district name",
    "why": "Why this matches the user's query"
  }
]

Focus on real, popular places in Hong Kong."""

    try:
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": context}
            ],
            max_tokens=800,
            temperature=0.7,
        )
        
        import json
        recommendations = json.loads(response.choices[0].message.content)
        return recommendations
        
    except Exception as e:
        print(f"❌ Recommendations error: {e}")
        return []
