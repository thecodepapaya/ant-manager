from __future__ import annotations

import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional

try:
    if sys.platform == "darwin":
        import EventKit
        from Foundation import NSDate
except ImportError:
    EventKit = None


@dataclass
class CalendarEvent:
    id: str
    title: str
    start_iso: str
    end_iso: str
    duration_minutes: int
    notes: Optional[str]
    location: Optional[str]
    calendar_name: str


def get_calendar_events(days: int = 7, start_date: Optional[datetime] = None) -> List[CalendarEvent]:
    if sys.platform != "darwin" or EventKit is None:
        return []

    store = EventKit.EKEventStore.alloc().init()
    
    # Check authorization status
    auth_status = EventKit.EKEventStore.authorizationStatusForEntityType_(0) # 0 = Event
    if auth_status == 0: # NotDetermined
        print("DEBUG: macOS Calendar access not determined. Requesting...", file=sys.stderr)
        # We can't easily wait for a callback in a CLI, but we can try to trigger the prompt
        store.requestAccessToEntityType_completion_(0, None)
    elif auth_status != 3: # 3 = Authorized
        print(f"DEBUG: macOS Calendar access denied or restricted (status: {auth_status}).", file=sys.stderr)
        print("DEBUG: Please grant 'Calendar' permission to your Terminal/Python in System Settings > Privacy & Security.", file=sys.stderr)
        return []

    if start_date:
        start_date_obj = start_date
        end_date_obj = start_date + timedelta(days=days)
    else:
        start_date_obj = datetime.now() - timedelta(days=days)
        end_date_obj = datetime.now() + timedelta(days=1)
    
    ns_start = NSDate.dateWithTimeIntervalSince1970_(start_date_obj.timestamp())
    ns_end = NSDate.dateWithTimeIntervalSince1970_(end_date_obj.timestamp())
    
    predicate = store.predicateForEventsWithStartDate_endDate_calendars_(
        ns_start, ns_end, None
    )
    
    events = store.eventsMatchingPredicate_(predicate)
    if not events:
        print(f"DEBUG: No macOS Calendar events found between {start_date_obj} and {end_date_obj}", file=sys.stderr)
        return []
        
    print(f"DEBUG: Found {len(events)} raw macOS Calendar events before filtering", file=sys.stderr)
    result: List[CalendarEvent] = []
    now = datetime.now(timezone.utc)
    
    for e in events:
        start_ts = e.startDate().timeIntervalSince1970()
        end_ts = e.endDate().timeIntervalSince1970()
        
        start_dt = datetime.fromtimestamp(start_ts, tz=timezone.utc)
        end_dt = datetime.fromtimestamp(end_ts, tz=timezone.utc)
        
        title = str(e.title() or "Untitled").lower()
        
        # Filter out birthday events and similar recurring all-day events
        if any(keyword in title for keyword in ['birthday', 'happy birthday', 'anniversary']):
            continue
        
        # Filter out all-day events
        if e.isAllDay():
            continue
        
        duration = int((end_ts - start_ts) / 60)
        
        result.append(
            CalendarEvent(
                id=str(e.eventIdentifier()),
                title=str(e.title() or "Untitled"),
                start_iso=start_dt.isoformat(),
                end_iso=end_dt.isoformat(),
                duration_minutes=duration,
                notes=str(e.notes()) if e.notes() else None,
                location=str(e.location()) if e.location() else None,
                calendar_name=str(e.calendar().title()) if e.calendar() else "Unknown",
            )
        )
        
    # Sort by start date descending
    result.sort(key=lambda x: x.start_iso, reverse=True)
    return result

