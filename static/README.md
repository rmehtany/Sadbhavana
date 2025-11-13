# Static Assets

This directory contains all client-side assets for the tree map application.

## Structure

```
static/
├── js/
│   └── map.js          # Main map logic (Leaflet + HTMX integration)
├── css/
│   └── styles.css      # Application styles
└── index.html          # Main application page
```

## Libraries Used

- **Leaflet.js** - Map rendering
- **HTMX** - Dynamic HTML updates
- Both loaded via CDN (no npm needed)

## Architecture

- Go backend handles all clustering logic
- JavaScript only handles map interaction and rendering
- HTMX fetches HTML fragments from Go endpoints
