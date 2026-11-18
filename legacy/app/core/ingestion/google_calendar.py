from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

from core import config

# If modifying these SCOPES, delete the file token.json.
SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]

def _get_client_config() -> Dict[str, Any]:
    cfg = config.load_config()
    client_id = cfg.google_client_id or os.environ.get("GOOGLE_CALENDAR_CLIENT_ID", "")
    client_secret = cfg.google_client_secret or os.environ.get("GOOGLE_CALENDAR_CLIENT_SECRET", "")
    
    return {
        "installed": {
            "client_id": client_id,
            "client_secret": client_secret,
            "auth_uri": "https://accounts.google.com/o/oauth2/auth",
            "token_uri": "https://oauth2.googleapis.com/token",
            "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
            "redirect_uris": ["http://localhost"],
        }
    }


def get_auth_url() -> str:
    """Returns the URL for the user to visit to authorize the app."""
    client_config = _get_client_config()
    if not client_config["installed"]["client_id"]:
        raise Exception("Google Calendar Client ID not configured.")
    
    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
    flow.redirect_uri = "http://localhost"
    auth_url, _ = flow.authorization_url(prompt='consent')
    return auth_url


def exchange_code_for_token(code: str) -> str:
    """Exchanges an authorization code for a token."""
    client_config = _get_client_config()
    flow = InstalledAppFlow.from_client_config(client_config, SCOPES)
    flow.redirect_uri = "http://localhost"
    flow.fetch_token(code=code)
    creds = flow.credentials
    return creds.to_json()


def _get_credentials() -> Optional[Credentials]:
    cfg = config.load_config()
    if not cfg.google_calendar_token:
        return None
    
    token_str = cfg.google_calendar_token
    
    # Check if this is a Firebase ID token
    if token_str.startswith('FIREBASE:'):
        # For Firebase tokens, we need to exchange them for Google OAuth tokens
        # This requires Firebase Admin SDK or a backend service
        # For now, we'll use the Firebase ID token to get user info
        # and then use that to get Google OAuth token
        # Note: This is a simplified approach - in production, you'd use Firebase Admin SDK
        firebase_id_token = token_str.replace('FIREBASE:', '')
        
        # Use the Firebase ID token to get Google OAuth token
        # This requires calling Google's tokeninfo endpoint and then exchanging
        # For now, return None and log that Firebase tokens need special handling
        print("Firebase token detected - Google Calendar access requires OAuth token exchange")
        return None
    
    # Handle legacy OAuth tokens (RAW: prefix or direct JSON)
    if token_str.startswith('RAW:'):
        token_str = token_str.replace('RAW:', '')
    
    try:
        token_data = json.loads(token_str)
    except json.JSONDecodeError:
        return None
    
    # If we have client_id and client_secret in config, use them
    client_config = _get_client_config()
    if client_config["installed"]["client_id"]:
        token_data['client_id'] = client_config['installed']['client_id']
        token_data['client_secret'] = client_config['installed']['client_secret']
    
    creds = Credentials.from_authorized_user_info(token_data, SCOPES)
    
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
        # Update stored token
        config.set_google_token(creds.to_json())
        
    return creds


def get_google_calendar_events(days: int = 7, start_date: Optional[datetime] = None) -> List[Dict[str, Any]]:
    creds = _get_credentials()
    if not creds:
        print("DEBUG: No Google Calendar credentials found.", file=sys.stderr)
        return []

    try:
        service = build("calendar", "v3", credentials=creds)

        # Call the Calendar API
        if start_date:
            time_min = start_date.isoformat()
            time_max = (start_date + timedelta(days=days)).isoformat()
        else:
            now = datetime.now(timezone.utc)
            # Fetch from 7 days ago to 1 day in the future if no date provided
            time_min = (now - timedelta(days=days)).isoformat()
            time_max = (now + timedelta(days=1)).isoformat()
        
        print(f"DEBUG: Fetching Google Calendar events between {time_min} and {time_max}", file=sys.stderr)
        
        params = {
            'calendarId': 'primary',
            'timeMin': time_min,
            'singleEvents': True,
            'orderBy': 'startTime',
        }
        if time_max:
            params['timeMax'] = time_max
        
        events_result = service.events().list(**params).execute()
        
        events = events_result.get('items', [])
        print(f"DEBUG: Found {len(events)} raw Google Calendar events before filtering", file=sys.stderr)
        
        result = []
        now = datetime.now(timezone.utc)
        
        for e in events:
            start = e['start'].get('dateTime', e['start'].get('date'))
            end = e['end'].get('dateTime', e['end'].get('date'))
            summary = e.get('summary', 'Untitled')
            title_lower = summary.lower()
            
            # Filter out birthday events and similar recurring all-day events
            if any(keyword in title_lower for keyword in ['birthday', 'happy birthday', 'anniversary']):
                print(f"DEBUG: Skipping '{summary}' (keyword match)", file=sys.stderr)
                continue
            
            # Filter out all-day events
            is_all_day = 'dateTime' not in e['start']
            if is_all_day:
                print(f"DEBUG: Skipping '{summary}' (all-day event)", file=sys.stderr)
                continue
            
            # Simple duration calc
            try:
                if 'T' in start:
                    start_dt = datetime.fromisoformat(start.replace('Z', '+00:00'))
                    end_dt = datetime.fromisoformat(end.replace('Z', '+00:00'))
                    duration = int((end_dt - start_dt).total_seconds() / 60)
                else:
                    duration = 1440 # 24 hours for all-day
            except Exception:
                duration = 0

            result.append({
                "id": e.get('id'),
                "title": summary,
                "start_iso": start,
                "end_iso": end,
                "duration_minutes": duration,
                "notes": e.get('description'),
                "location": e.get('location'),
                "calendar_name": "Google Calendar (primary)"
            })
            
        return result
    except Exception as e:
        print(f"Error fetching Google Calendar events: {e}")
        return []

