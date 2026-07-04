---
id: geospatial-features
category: skill
tags: [postgis, spatial-queries, distance, nearby-search]
capabilities:
  - PostGIS with Supabase
  - Spatial queries
  - Distance calculations
  - Nearby search
useWhen:
  - Implementing nearby search
  - Calculating distances
  - Working with geospatial data
---

# Geospatial Features

Geospatial queries and features with PostGIS.

## Supabase PostGIS Setup

```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create table with location column
CREATE TABLE places (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  location GEOGRAPHY(POINT, 4326),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create spatial index
CREATE INDEX places_location_idx ON places USING GIST (location);

-- Insert with coordinates
INSERT INTO places (name, location)
VALUES ('Coffee Shop', ST_MakePoint(-122.4194, 37.7749));
```

## Nearby Search

```sql
-- Find places within 5km
CREATE OR REPLACE FUNCTION nearby_places(
  lat FLOAT,
  lng FLOAT,
  radius_meters INT DEFAULT 5000
)
RETURNS SETOF places
LANGUAGE sql
AS $$
  SELECT *
  FROM places
  WHERE ST_DWithin(
    location,
    ST_MakePoint(lng, lat)::geography,
    radius_meters
  )
  ORDER BY location <-> ST_MakePoint(lng, lat)::geography;
$$;
```

## Client Usage

```typescript
// Call nearby search function
const { data: nearbyPlaces } = await supabase
  .rpc('nearby_places', {
    lat: userLocation.latitude,
    lng: userLocation.longitude,
    radius_meters: 5000,
  })

// With distance calculation
const { data } = await supabase
  .rpc('nearby_places_with_distance', {
    lat: 37.7749,
    lng: -122.4194,
  })
// Returns: [{ name: 'Coffee Shop', distance_meters: 150 }, ...]
```

## Distance Calculation

```sql
-- Function to get places with distance
CREATE OR REPLACE FUNCTION nearby_places_with_distance(
  lat FLOAT,
  lng FLOAT,
  radius_meters INT DEFAULT 5000
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  distance_meters FLOAT
)
LANGUAGE sql
AS $$
  SELECT
    id,
    name,
    ST_Distance(
      location,
      ST_MakePoint(lng, lat)::geography
    ) as distance_meters
  FROM places
  WHERE ST_DWithin(
    location,
    ST_MakePoint(lng, lat)::geography,
    radius_meters
  )
  ORDER BY distance_meters;
$$;
```

## Client-Side Distance

```typescript
// Haversine formula for client-side distance
function getDistance(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const R = 6371e3 // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180
  const φ2 = (lat2 * Math.PI) / 180
  const Δφ = ((lat2 - lat1) * Math.PI) / 180
  const Δλ = ((lon2 - lon1) * Math.PI) / 180

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2)

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  return R * c // Distance in meters
}
```

## Best Practices

- Use spatial indexes for performance
- Store coordinates in GEOGRAPHY type
- Calculate distance server-side when possible
- Cache nearby results appropriately
