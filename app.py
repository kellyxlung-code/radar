import json
import streamlit as st
import requests
import pandas as pd
from streamlit_folium import st_folium
import folium

API = "http://127.0.0.1:8000"

st.set_page_config(page_title="Radar Demo", layout="centered")
st.title("🎯 Radar Demo")

# Keep candidate result between reruns
if "candidate" not in st.session_state:
    st.session_state["candidate"] = {}
if "name_to_save" not in st.session_state:
    st.session_state["name_to_save"] = ""
if "selected_suggestion" not in st.session_state:
    st.session_state["selected_suggestion"] = None

tab_map, tab_add, tab_import = st.tabs(["🗺️ Map", "➕ Add Place", "🔗 Import from Link"])

# -----------------------------
# MAP TAB (with emoji markers only)
# -----------------------------
with tab_map:
    st.subheader("Your Saved Places")

    # Load from backend
    try:
        r = requests.get(f"{API}/places")
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        st.error(f"Failed to load places: {e}")
        data = []

    if not data:
        st.info("No places yet. Import some from Instagram or add manually!")
    else:
        df = pd.DataFrame(data)

        # Emoji icons by category
        icon_map = {
            "Cafe": "☕️",
            "Food": "🍽️",
            "Bar": "🍸",
            "Activity": "🎯",
            "Shop": "🛍️",
            "Other": "📍"
        }

        # Create the map
        m = folium.Map(location=[22.279, 114.162], zoom_start=13)

        # Add emoji markers (visible icons) - FIXED INDENTATION
        for _, row in df.iterrows():
            emoji = icon_map.get(row.get("category", "Other"), "📍")
            html_icon = folium.DivIcon(
                html=f"""
                <div style='font-size:24px; text-align:center; transform: translate(-12px, -12px);'>
                    {emoji}
                </div>
                """
            )
            folium.Marker(
                [row.lat, row.lng],
                tooltip=f"{row.name}",
                popup=f"""
                    <b>{row.name}</b><br>
                    {row.district or ''}<br>
                    {row.category}<br>
                    <a href='{row.source}' target='_blank' style='color:#4DA3FF;text-decoration:none;'>Open post ↗️</a>
                """,
                icon=html_icon
            ).add_to(m)

        st_folium(m, width=720, height=480)
        
        # Show list of places
        st.markdown("---")
        st.markdown("### Saved Places")
        for idx, row in df.iterrows():
            col1, col2, col3 = st.columns([3, 2, 1])
            with col1:
                st.markdown(f"**{row['name']}**")
            with col2:
                st.caption(f"{row.get('district', '—')} • {row.get('category', 'Other')}")
            with col3:
                if row.get('source') and row['source'] != 'manual':
                    st.markdown(f"[🔗]({row['source']})")

# -----------------------------
# ADD PLACE TAB (manual)
# -----------------------------
with tab_add:
    st.subheader("Add a place manually")
    name = st.text_input("Place Name")
    district = st.text_input("District", "Central")
    category = st.selectbox("Category", ["Cafe", "Food", "Bar", "Activity", "Shop", "Other"])
    lat = st.number_input("Latitude", value=22.279, format="%.6f")
    lng = st.number_input("Longitude", value=114.162, format="%.6f")

    if st.button("💾 Save Place"):
        if not name or not name.strip():
            st.error("Please enter a place name!")
        else:
            payload = {
                "name": name.strip(),
                "district": district,
                "category": category,
                "lat": float(lat),
                "lng": float(lng),
                "address": "",
                "source": "manual",
            }
            try:
                resp = requests.post(f"{API}/places", json=payload, timeout=15)
                if resp.ok:
                    st.success("✅ Saved! Check the Map tab.")
                    st.balloons()
                else:
                    st.error(f"Failed to save: {resp.status_code} {resp.text}")
            except Exception as e:
                st.error(f"Error: {e}")

# -----------------------------
# IMPORT FROM LINK TAB - WITH MANUAL FALLBACK UI
# -----------------------------
with tab_import:
    st.subheader("Import from Instagram/RED/Facebook")
    
    st.markdown("""
    Paste a link to a social media post that mentions a place in Hong Kong.
    
    **Examples:**
    - Instagram: `https://www.instagram.com/p/ABC123/`
    - Facebook: `https://www.facebook.com/username/posts/123`
    - RED (小红书): `https://www.xiaohongshu.com/explore/ABC123`
    """)
    
    url = st.text_input("📎 Post URL", placeholder="https://www.instagram.com/p/...")

    if st.button("🔍 Extract Place Info"):
        if not url or not url.strip():
            st.error("Please enter a URL!")
            st.stop()
            
        with st.spinner("Extracting place information..."):
            try:
                resp = requests.post(f"{API}/import-url", json={"url": url.strip()}, timeout=20)
                resp.raise_for_status()
                data = resp.json()
            except Exception as e:
                st.error(f"❌ Import failed: {e}")
                st.stop()

        # Persist candidate
        st.session_state["candidate"] = data.get("candidate", {}) or {}
        cand = st.session_state["candidate"]
        needs_review = data.get("needs_review", False)
        suggestions = data.get("suggestions", [])

        # Show extraction result
        st.markdown("---")
        st.markdown("### 📊 Extraction Result")
        
        # Confidence indicator
        confidence = cand.get("confidence", 0)
        if confidence >= 0.7:
            st.success(f"✅ High confidence extraction ({confidence:.0%})")
        elif confidence >= 0.5:
            st.warning(f"⚠️ Medium confidence extraction ({confidence:.0%})")
        else:
            st.error(f"❌ Low confidence extraction ({confidence:.0%}) - Please review!")

        # Show extracted info
        col1, col2 = st.columns(2)
        with col1:
            st.markdown(f"**Name:** {cand.get('name', 'Unknown')}")
            st.markdown(f"**District:** {cand.get('district', '—')}")
            st.markdown(f"**Category:** {cand.get('category', 'Other')}")
        with col2:
            st.markdown(f"**Address:** {cand.get('address', '—')}")
            st.markdown(f"**Coordinates:** {cand.get('lat', 0):.4f}, {cand.get('lng', 0):.4f}")
            st.markdown(f"**Query Used:** {cand.get('query_used', '—')}")

        # Show raw response in expander
        with st.expander("🔍 View Raw API Response"):
            st.json(data)

        # --- MANUAL FALLBACK UI ---
        if needs_review and suggestions:
            st.markdown("---")
            st.markdown("### 🤔 Not sure? Pick the correct place:")
            
            for idx, sug in enumerate(suggestions):
                col1, col2 = st.columns([4, 1])
                with col1:
                    st.markdown(f"**{sug.get('name', 'Unknown')}**")
                    st.caption(sug.get('address', '—'))
                with col2:
                    if st.button("✅ Use this", key=f"sug_{idx}"):
                        # Update candidate with selected suggestion
                        st.session_state["candidate"]["name"] = sug.get("name", "Unknown")
                        st.session_state["candidate"]["address"] = sug.get("address", "")
                        st.session_state["candidate"]["lat"] = sug.get("lat", 22.279)
                        st.session_state["candidate"]["lng"] = sug.get("lng", 114.162)
                        st.session_state["candidate"]["confidence"] = 0.9
                        st.session_state["selected_suggestion"] = idx
                        st.rerun()
            
            st.markdown("---")
            st.markdown("**Or enter manually:**")

        # Manual correction fields
        st.markdown("### ✏️ Review & Edit")
        
        col1, col2 = st.columns(2)
        with col1:
            name_to_save = st.text_input(
                "Place Name",
                value=cand.get("name", "Unknown"),
                key="name_input"
            )
            district_to_save = st.text_input(
                "District",
                value=cand.get("district", ""),
                key="district_input"
            )
        with col2:
            category_to_save = st.selectbox(
                "Category",
                ["Food", "Cafe", "Bar", "Activity", "Shop", "Other"],
                index=["Food", "Cafe", "Bar", "Activity", "Shop", "Other"].index(cand.get("category", "Other")),
                key="category_input"
            )
            address_to_save = st.text_input(
                "Address (optional)",
                value=cand.get("address", ""),
                key="address_input"
            )

        # Save button
        if st.button("💾 Save to My Places", type="primary"):
            if not name_to_save or name_to_save.strip() == "Unknown":
                st.error("⚠️ Please enter a valid place name!")
            else:
                payload = {
                    "name": name_to_save.strip(),
                    "lat": cand.get("lat", 22.279),
                    "lng": cand.get("lng", 114.162),
                    "district": district_to_save.strip(),
                    "category": category_to_save,
                    "address": address_to_save.strip(),
                    "source": url.strip(),
                }
                try:
                    r2 = requests.post(f"{API}/places", json=payload, timeout=15)
                    if r2.ok:
                        st.success("✅ Saved! Go to the Map tab to see your pin.")
                        st.balloons()
                        # Clear state
                        st.session_state["candidate"] = {}
                        st.session_state["selected_suggestion"] = None
                    else:
                        st.error(f"❌ Save failed: {r2.status_code} {r2.text}")
                except Exception as e:
                    st.error(f"❌ Error: {e}")

# Footer
st.markdown("---")
st.caption("🎯 Radar MVP - Built for HKUST Demo")
