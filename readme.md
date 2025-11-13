# Tree Mapping Project - Implementation Summary

A complete **Go + HTMX + PostGIS** tree mapping application with server-side clustering, following the minimal JavaScript philosophy.

## Project Structure

```
project/
├── db/
│   ├── queries/           # SQL query files for sqlc
│   │   ├── trees.sql      # ⭐ Core clustering queries
│   │   ├── towns.sql      # Town management
│   │   ├── donors.sql     # Donor management
│   │   └── tree_updates.sql # Tree updates & files
│   ├── migrations/
│   │   └── 20251110182154_init.sql  # Schema with PostGIS
│   ├── conn.go            # Database connection with singleton pattern
|   └── sqlc.yaml          # Sqlc configuration
├── web/                   # HTTP handlers module
│   ├── models.go          # Request/response DTOs
│   ├── handlers.go        # Business logic & clustering
│   └── endpoints.go       # Huma route registration
└── main.go                # Application entry point
```

## Key Implementation Details

**Three Clustering Strategies:**

1. **Town Clusters** (zoom 1-8): `GetTreesByTownCluster`
   - Groups by town
   - Returns aggregate counts and center points

2. **Grid Clusters** (zoom 9-12): `GetTreesByGridCluster`
   - Uses `ST_SnapToGrid` for spatial clustering
   - Dynamic grid size based on zoom level

3. **Individual Trees** (zoom 13+): `GetIndividualTrees`
   - Returns actual tree locations
   - Includes donor and town details
   - Limited to 1000 for performance

### 2. Web Module (`web/`)

**models.go** - Type Definitions:
- `GetMarkersInput` - Viewport bounds validation
- `Marker` - Unified marker structure for all types
- `TreeDetail` - Complete tree information
- `ClusterDetail` - Town statistics
- `MarkerType` enum - town-cluster, grid-cluster, tree

**handlers.go** - Business Logic:
- `GetMarkers()` - Routes to appropriate clustering method
- `calculateGridSize()` - Dynamic grid sizing formula
- Conversion functions for DB → API types
- JSON metadata parsing

**endpoints.go** - HTTP Routes:
- Uses `db.NewQueries(ctx)` for singleton connection
- Returns HTML fragments with data attributes
- Inline templates for markers, tree details, cluster details

### 4. Architecture Decisions

✅ **Server-Side Clustering** - All clustering logic in Go/PostgreSQL  
✅ **Named SQL Parameters** - Better generated Go code  
✅ **Singleton DB Connection** - Efficient connection pooling  
✅ **HTML Fragments** - HTMX-friendly responses  
✅ **Type Safety** - Huma validates all inputs  
✅ **String IDs** - Uses nanoid format (CHAR(21))  

## API Endpoints

### GET /api/markers
Returns clustered or individual markers based on zoom level.

**Query Parameters:**
- `north`, `south`, `east`, `west` (float64, -90 to 90, -180 to 180)
- `zoom` (int, 1-20)

**Response:** HTML fragment with data attributes
```html
<div id="marker-container">
  <div class="marker-data" data-type="..." data-lat="..." ...></div>
</div>
```

### GET /api/tree/{id}
Returns detailed information about a specific tree.

**Path Parameter:**
- `id` (string, 21 chars, pattern: `TRE_[A-Za-z0-9_-]{17}`)

**Response:** HTML detail panel

### GET /api/cluster/{townCode}
Returns statistics for a town cluster.

**Path Parameter:**
- `townCode` (string, 2 chars)

**Response:** HTML detail panel with aggregations

## How It Works Together

```
1. User pans/zooms map
   ↓
2. JavaScript reads map bounds and zoom
   ↓
3. HTMX sends GET /api/markers?north=...&zoom=...
   ↓
4. Go handler determines clustering strategy
   ↓
5. PostGIS executes spatial query with clustering
   ↓
6. Go converts DB results → Marker DTOs
   ↓
7. Go renders HTML fragment with data attributes
   ↓
8. HTMX swaps HTML into #marker-container
   ↓
9. JavaScript reads data attributes and creates Leaflet markers
```

## Performance Characteristics

- **Zoom 1-8**: ~10-50 town clusters (milliseconds)
- **Zoom 9-12**: ~50-200 grid clusters (tens of milliseconds)  
- **Zoom 13+**: Up to 1000 individual trees (hundreds of milliseconds)
- **Spatial Index**: GIST index makes all queries fast
- **Connection Pool**: 5-30 connections, reused efficiently