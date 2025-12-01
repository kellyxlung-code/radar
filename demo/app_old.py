import json
import streamlit as st
import requests
import pandas as pd
from streamlit_folium import st_folium
import folium

API = "http://127.0.0.1:8000"

st.set_page_config(page_title="Radar Demo", layout="centered")
st.title("Radar Demo")

# Keep candidate result between reruns
if "candidate" not in st.session_state:
    st.session_state["candidate"] = {}
if "name_to_save" not in st.session_state:
    st.session_state["name_to_save"] = ""

tab_map, tab_add, tab_import = st.tabs(["Map", "Add Place", "Import from Link"])

# -----------------------------
# MAP TAB (with emoji markers only)
# -----------------------------
with tab_map:
    st.subheader("Pins")

    # Load from backend
    try:
        r = requests.get(f"{API}/places")
        r.raise_for_status()
        data = r.json()
    except Exception as e:
        st.error(f"Failed to load places: {e}")
        data = []

    if not data:
        st.info("No places yet.")
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

# Add emoji markers (visible icons)
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

# -----------------------------
# ADD PLACE TAB (manual)
# -----------------------------
with tab_add:
    st.subheader("Add a place")
    name = st.text_input("Name")
    district = st.text_input("District", "Central")
    category = st.selectbox("Category", ["Cafe", "Food", "Bar", "Activity", "Shop", "Other"])
    lat = st.number_input("Lat", value=22.279, format="%.6f")
    lng = st.number_input("Lng", value=114.162, format="%.6f")

    if st.button("Save (manual)"):
        payload = {
            "name": (name or "Unknown").strip(),
            "district": district,
            "category": category,
            "lat": float(lat),
            "lng": float(lng),
            "address": "",
            "source": "manual",
        }
        resp = requests.post(f"{API}/places", json=payload, timeout=15)
        st.write("POST /places →", resp.status_code, resp.text)  # DEBUG
        if resp.ok:
            st.success("Saved! Check the Map tab.")

# -----------------------------
# IMPORT FROM LINK TAB
# -----------------------------
with tab_import:
    st.subheader("Paste an Instagram/RED URL")
    url = st.text_input("Post URL")

    if st.button("Fetch place"):
        try:
            resp = requests.post(f"{API}/import-url", json={"url": url}, timeout=15)
            st.write(f"POST /import-url → {resp.status_code}")
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            st.error(f"Import failed: {e}")
            st.stop()

        # persist candidate
        st.session_state["candidate"] = data.get("candidate", {}) or {}
        cand = st.session_state["candidate"]

        # show raw json
        with st.expander("Raw backend response"):
            st.code(json.dumps(data, indent=2))

        # preview
        st.markdown(f"**Candidate:** {cand.get('name','Unknown')}")
        st.caption(f"{cand.get('district','—')} — {cand.get('category','Cafe')}")

        # prefill name
        st.session_state["name_to_save"] = cand.get("name") or "Unknown"

    name_to_save = st.text_input(
        "Name to save",
        value=st.session_state.get("name_to_save",""),
        key="name_to_save_input"
    )

    if st.button("Save to my pins"):
        cand = st.session_state.get("candidate", {}) or {}
        payload = {
            "name": name_to_save or cand.get("name","Unknown"),
            "lat": cand.get("lat", 22.279),
            "lng": cand.get("lng", 114.162),
            "district": cand.get("district",""),
            "category": cand.get("category","Cafe"),
            "address": cand.get("address",""),
            "source": "import",
        }
        r2 = requests.post(f"{API}/places", json=payload, timeout=15)
        if r2.ok:
            st.success("Saved! Go to the Map tab to see your pin.")
        else:
            st.error(f"Save failed: {r2.status_code} {r2.text}")
