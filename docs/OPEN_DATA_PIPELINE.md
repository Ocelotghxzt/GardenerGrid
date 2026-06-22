# GardenerGrid Open-Data Pipeline

This project now supports a large open-data plant encyclopedia and API-assisted identification.

## Open APIs Used
- Encyclopedia taxonomy and metadata: GBIF API
  - https://api.gbif.org/v1/species/search
  - https://api.gbif.org/v1/occurrence/search
- Almanac astronomy (sunrise/sunset/daylight): Open-Meteo API (no key)
  - https://api.open-meteo.com/v1/forecast
- Photo ID enhancement (image CV): iNaturalist public identify endpoint
  - https://www.inaturalist.org/observations/identify

## Generate 10,000+ Plant Entries
From repository root:

- Metadata only:
  - npm run build:plants:10k
- Metadata with remote image URLs:
  - npm run build:plants:10k:with-media
- Metadata + offline image pack download:
  - npm run build:plants:10k:offline-pack

The output is written to:
- assets/data/plants_10000.json

Offline images (optional) are written to:
- assets/images/encyclopedia/

## Runtime Behavior
- Encyclopedia provider loads assets/data/plants_10000.json if present, otherwise falls back to assets/data/plants.json.
- Plant ID first attempts open-data image identification when a photo is provided; if unavailable, it falls back to local descriptor matching.
- Almanac loads live astronomy values using device location and Open-Meteo; if unavailable, core moon/frost/planting logic still works offline.

## Notes on Scale
- 10k metadata entries are practical for local SQLite caching.
- 10k full-resolution offline images can be very large. Use lower MAX_IMAGES for mobile builds if app size is a concern.
- Consider splitting image packs by region or biome for field deployments.
