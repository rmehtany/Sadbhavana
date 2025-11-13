// Tree Map Application - Map Management
// Handles Leaflet map initialization and marker interactions

const MapManager = {
  map: null,
  markers: [],
  markerLayer: null,

  // Initialize the map
  init(lat = 40.7128, lng = -74.0060, zoom = 10) {
    // Check for URL parameters to override defaults
    const params = new URLSearchParams(window.location.search);
    const urlLat = params.get('lat');
    const urlLng = params.get('lng');
    const urlZoom = params.get('zoom');

    const centerLat = urlLat ? parseFloat(urlLat) : lat;
    const centerLng = urlLng ? parseFloat(urlLng) : lng;
    const centerZoom = urlZoom ? parseInt(urlZoom) : zoom;

    // Create map
    this.map = L.map('map').setView([centerLat, centerLng], centerZoom);

    // Add OpenStreetMap tiles
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 19,
      minZoom: 1
    }).addTo(this.map);

    // Create a layer group for markers
    this.markerLayer = L.layerGroup().addTo(this.map);

    console.log(`Map initialized at [${centerLat}, ${centerLng}], zoom ${centerZoom}`);

    // Set up event listeners
    this.setupEventListeners();

    // Load initial markers
    this.loadMarkers();
  },

  // Set up all event listeners
  setupEventListeners() {
    // Listen for map movement (pan/zoom)
    this.map.on('moveend', () => {
      this.loadMarkers();
    });

    // Listen for zoom-to-location button clicks (from detail panel)
    document.addEventListener('click', (e) => {
      if (e.target.classList.contains('zoom-to-location')) {
        const lat = parseFloat(e.target.dataset.lat);
        const lng = parseFloat(e.target.dataset.lng);
        const zoom = parseInt(e.target.dataset.zoom || 16);
        this.map.flyTo([lat, lng], zoom);
      }

      // Listen for zoom-to-town button clicks
      if (e.target.classList.contains('zoom-to-town')) {
        const townCode = e.target.dataset.townCode;
        this.zoomToTown(townCode);
      }
    });
  },

  // Load markers from server based on current viewport
  loadMarkers() {
    const bounds = this.map.getBounds();
    const zoom = this.map.getZoom();

    const params = new URLSearchParams({
      north: bounds.getNorth(),
      south: bounds.getSouth(),
      east: bounds.getEast(),
      west: bounds.getWest(),
      zoom: zoom
    });

    // Show loading indicator
    this.showLoading(true);

    // Use HTMX to fetch markers
    htmx.ajax('GET', `/api/markers?${params.toString()}`, {
      target: '#marker-container',
      swap: 'innerHTML'
    }).then(() => {
      this.updateMarkers();
      this.showLoading(false);
    }).catch((error) => {
      console.error('Failed to load markers:', error);
      this.showLoading(false);
    });
  },

  // Update markers on map from DOM data
  updateMarkers() {
    // Clear existing markers
    this.markerLayer.clearLayers();
    this.markers = [];

    // Read marker data from DOM (populated by HTMX)
    const markerElements = document.querySelectorAll('.marker-data');
    
    console.log(`Updating ${markerElements.length} markers on map`);

    markerElements.forEach(el => {
      const type = el.dataset.type;
      const lat = parseFloat(el.dataset.lat);
      const lng = parseFloat(el.dataset.lng);
      const count = parseInt(el.dataset.count) || 0;
      const id = el.dataset.id;
      const label = el.dataset.label || '';

      // Create appropriate marker icon
      const icon = this.getMarkerIcon(type, count);

      // Create marker
      const marker = L.marker([lat, lng], { icon: icon }).addTo(this.markerLayer);

      // Add popup with label
      if (label) {
        marker.bindPopup(label);
      }

      // Handle click based on marker type
      marker.on('click', () => {
        if (type === 'grid-cluster') {
          // Grid cluster: zoom to level 13 at cluster centroid
          this.map.flyTo([lat, lng], 13);
        } else {
          // Town cluster or individual tree: show detail panel
          htmx.trigger(el, 'click');
          this.showDetailPanel();
        }
      });

      this.markers.push(marker);
    });
  },

  // Get appropriate marker icon based on type
  getMarkerIcon(type, count) {
    let iconHtml = '';
    let className = 'custom-marker';

    if (type === 'town-cluster') {
      iconHtml = `<div class="marker-cluster town-cluster">
                    <span>${count}</span>
                  </div>`;
      className += ' town-cluster-icon';
    } else if (type === 'grid-cluster') {
      iconHtml = `<div class="marker-cluster grid-cluster">
                    <span>${count}</span>
                  </div>`;
      className += ' grid-cluster-icon';
    } else {
      // Individual tree
      iconHtml = `<div class="marker-tree">🌳</div>`;
      className += ' tree-icon';
    }

    return L.divIcon({
      html: iconHtml,
      className: className,
      iconSize: [40, 40],
      iconAnchor: [20, 40],
      popupAnchor: [0, -40]
    });
  },

  // Show/hide loading indicator
  showLoading(show) {
    const loading = document.getElementById('loading');
    if (show) {
      loading.classList.add('active');
    } else {
      loading.classList.remove('active');
    }
  },

  // Show detail panel
  showDetailPanel() {
    document.getElementById('detail-panel').classList.add('active');
  },

  // Zoom to town by fetching cluster detail for centroid
  zoomToTown(townCode) {
    this.showLoading(true);

    // Fetch cluster detail JSON to get the town's centroid
    fetch(`/api/cluster/${townCode}/raw`)
      .then(response => response.json())
      .then(data => {
        const lat = data.CenterLat;
        const lng = data.CenterLng;
        this.map.flyTo([lat, lng], 8);
        this.showLoading(false);
      })
      .catch(error => {
        console.error('Failed to fetch town center:', error);
        this.showLoading(false);
      });
  }
};

// Close detail panel (called from button)
function closeDetailPanel() {
  document.getElementById('detail-panel').classList.remove('active');
}

// Initialize map when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  MapManager.init();
});