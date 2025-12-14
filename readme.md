# Sadbhavana Tree Project Management System

A comprehensive tree tracking and donor management platform for [Sadbhavana Vruddhashram](https://sadbhavnadham.org/), supporting their mission to plant and nurture over 151 crore trees across India.

## Goals of the Project

Sadbhavana's tree plantation initiative goes beyond simply planting trees—it's about creating lasting environmental impact through careful nurturing and transparent tracking. This project aims to:

1. **Enable Transparent Donor Engagement**: Allow donors to see exactly where their contributions are making an impact, with geographic visualization of tree planting projects and individual trees.

2. **Streamline Administrative Operations**: Provide administrators with efficient tools to manage donor records, tree planting projects, and individual tree data at scale.

3. **Facilitate Tree Monitoring & Care**: Support Sadbhavana's unique commitment to nurturing each tree for at least 4 years through automated image processing and tracking via WhatsApp integration.

4. **Build Community Connection**: Create a visual, interactive map that connects donors, volunteers, and the public with the environmental restoration happening across villages in Gujarat and beyond.

5. **Ensure Long-term Accountability**: Maintain comprehensive records with photographic evidence of each tree's growth, supporting Sadbhavana's promise that "planting trees is easy, but caring for them is difficult—and we take complete responsibility."

## Getting Started

### Prerequisites

- **Docker Desktop** (installation instructions below)
- **Git** for cloning the repository
- **.env file** from project maintainer (Rushabh)

### Installation Steps

#### 1. Clone the Repository

```bash
git clone <repository-url>
cd <repository-name>
```

#### 2. Install Docker Desktop

**For MacOS/Linux users:**
1. Visit [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
2. Download Docker Desktop for Mac
3. Open the downloaded `.dmg` file and drag Docker to Applications
4. Launch Docker from Applications

**For Windows users:**
1. Visit [https://www.docker.com/products/docker-desktop/](https://www.docker.com/products/docker-desktop/)
2. Download Docker Desktop for Windows
3. Run the installer
4. **Important**: Reboot your computer after installation
   - **Note for some users**: During the reboot, you may need to enter your system's BIOS/UEFI settings to enable virtualization (VT-x/AMD-V). This varies by manufacturer:
     - Press `F2`, `F10`, `Del`, or `F12` during boot (check your PC's startup screen)
     - Navigate to "Advanced" or "CPU Configuration"
     - Enable "Intel Virtualization Technology" or "AMD-V"
     - Save and exit
5. Launch Docker Desktop after reboot

#### 3. Configure Environment Variables

1. Obtain the `.env` file from Rushabh
2. Place the `.env` file in the root directory of the repository

#### 4. Start the Application

```bash
docker compose up
```

This command will:
- Start PostgreSQL with PostGIS extension
- Launch the Go backend server with HTMX/templ

#### 5. Access the Application

Once the containers are running, navigate to:
- **Map View**: [http://localhost:8080/map](http://localhost:8080/map)
- **Admin Panel**: [http://localhost:8080/admin](http://localhost:8080/admin)

#### 6. Setting up Development Environment

**For MacOS/Linux Users**
1. Follow the guide [here](https://github.com/moovweb/gvm) to set up gvm, and install go1.25 (set to default)

**For Windows Users**
1. In VSCode, press `Ctrl+Shift+P` to enter command palette
2. Type `Terminal: Select Default Profile`
3. Enter `Git Bash`
4. Follow the instructions [here](https://go.dev/dl/) to install go 1.25

**For Both**
1. Install the following extensions
  - Go (By Go Team at Google)
  - PostgreSQL (By Database Client)
  - Templ Go To Definition (By Louis Laugesen)
  - templ-vscode (By a-h)
  - Todo Tree (By Gruntfuggly)
  - YAML (By Red Hat)
2. 


## System Overview

### Technology Stack

- **Database**: PostgreSQL with PostGIS extension for geospatial data
- **Backend**: Go (Golang)
- **Frontend**: HTMX + templ for server-side rendering
- **Database Access**: SQLc (migrating to stored procedures for better encapsulation)
- **Local Development**: Docker Compose + ngrok (for webhook tunneling)

### Key Features & Workflows

#### 1. Admin Panel (`/admin`)

Administrators can:
- **Create and manage donor records**: Track contributions and donor information
- **Create tree planting projects**: Define geographic areas and project details
- **Create tree records**: Log individual trees with GPS coordinates, species, planting date, and photos
- **View dashboards**: Monitor project progress and tree survival rates

#### 2. Interactive Map View (`/map`)

Public-facing interface that allows:
- **Explore planting projects**: See all active and completed tree planting initiatives on an interactive map
- **View individual trees**: Click on tree markers to see photos, species information, planting date, and growth updates
- **Donor transparency**: See which donors contributed to specific projects
- **Filter and search**: Find projects by location, date, or species

#### 3. WhatsApp Integration (Webhook)

Automated tree monitoring system:
- **Receive images**: WhatsApp webhook accepts photos of trees sent by field staff
- **AI-powered analysis**: Images are processed via Google Gemini to identify which tree record they belong to
- **Automatic updates**: Database is updated with new photos and timestamps
- **Status tracking**: Helps verify that trees are being properly maintained during the critical 4-year nurturing period

### Architecture Diagram

```
┌─────────────┐
│   Donors &  │
│   Public    │
└──────┬──────┘
       │
       ▼
┌─────────────────┐      ┌──────────────┐
│  HTMX Frontend  │◄────►│ Go Backend   │
│  (Map + Admin)  │      │ (templ)      │
└─────────────────┘      └──────┬───────┘
                                │
                    ┌───────────┼───────────┐
                    ▼           ▼           ▼
              ┌──────────┐ ┌──────┐  ┌──────────┐
              │PostgreSQL│ │Gemini│  │ WhatsApp │
              │+ PostGIS │ │  AI  │  │ Webhook  │
              └──────────┘ └──────┘  └──────────┘
```

### Database Migration Strategy

The project is currently transitioning from SQLc-generated queries to stored procedures:
- **Current**: SQLc for type-safe SQL query generation
- **Target**: PostgreSQL stored procedures for better:
  - Encapsulation of business logic
  - Performance optimization
  - Easier maintenance and testing
  - Clearer API boundaries

## Development Status

### Current State
✅ Admin panel for data management  
✅ Interactive map with tree/project visualization  
✅ WhatsApp webhook with AI image processing  
✅ Local development environment via Docker Compose  

### TODO
⏳ Production deployment setup  
⏳ Complete migration to stored procedures  

## Contributing

This project supports Sadbhavana Vruddhashram's mission to make India greener by planting and nurturing trees with complete responsibility. Every contribution helps create transparency and efficiency in environmental restoration.

For questions or access to the `.env` file, contact Rushabh.

---

*"Planting trees is easy, but caring for them is difficult. At Sadbhavana, we take complete responsibility for their maintenance."* — Sadbhavana Vruddhashram