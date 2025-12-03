"""
Helper functions for AI extraction
"""

import re


def extract_district(text: str) -> str:
    """
    Extract Hong Kong district from text.
    """
    HK_DISTRICTS = [
        "Central", "Sheung Wan", "Wan Chai", "Causeway Bay", "Admiralty",
        "Tsim Sha Tsui", "TST", "Mong Kok", "Jordan", "Yau Ma Tei",
        "Sai Kung", "Stanley", "Repulse Bay", "Aberdeen", "Kennedy Town",
        "Sham Shui Po", "Kwun Tong", "Tai Hang", "Tin Hau", "Fortress Hill",
        "North Point", "Quarry Bay", "Tai Koo", "Shau Kei Wan",
        "Hung Hom", "To Kwa Wan", "Kowloon City", "Diamond Hill",
        "Wong Tai Sin", "Kowloon Tong", "Prince Edward"
    ]
    
    text_lower = text.lower()
    for district in HK_DISTRICTS:
        if district.lower() in text_lower:
            return district
    
    return None


def extract_tags(caption: str) -> list:
    """Extract relevant tags from caption"""
    # Extract hashtags
    hashtags = re.findall(r'#(\w+)', caption)
    
    # Common keywords
    keywords = []
    keyword_patterns = [
        "brunch", "lunch", "dinner", "breakfast",
        "coffee", "cafe", "bar", "cocktail",
        "aesthetic", "minimal", "cozy", "vibes",
        "instagrammable", "photogenic", "hidden gem"
    ]
    
    caption_lower = caption.lower()
    for keyword in keyword_patterns:
        if keyword in caption_lower:
            keywords.append(keyword)
    
    all_tags = list(set(hashtags + keywords))
    return all_tags[:10]
