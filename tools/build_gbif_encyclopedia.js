/* eslint-disable no-console */
const fs = require('fs');
const path = require('path');
const axios = require('axios');

const args = process.argv.slice(2);

function argValue(flag, fallback) {
  const index = args.indexOf(flag);
  if (index === -1 || index + 1 >= args.length) return fallback;
  return args[index + 1];
}

function hasFlag(flag) {
  return args.includes(flag);
}

const TARGET = Number(argValue('--target', process.env.TARGET_PLANTS || 10000));
const PAGE_SIZE = Number(argValue('--page-size', 300));
const INCLUDE_MEDIA = hasFlag('--include-media') || process.env.INCLUDE_MEDIA === '1';
const DOWNLOAD_IMAGES = hasFlag('--download-images') || process.env.DOWNLOAD_IMAGES === '1';
const MAX_IMAGES = Number(argValue('--max-images', process.env.MAX_IMAGES || 2500));
const OUTPUT_FILE = argValue('--output', process.env.OUTPUT_FILE || 'assets/data/plants_10000.json');
const IMAGE_DIR = argValue('--image-dir', process.env.IMAGE_DIR || 'assets/images/encyclopedia');
const REQUEST_DELAY_MS = Number(argValue('--delay-ms', process.env.REQUEST_DELAY_MS || 120));

const client = axios.create({
  timeout: 25000,
  headers: {
    'User-Agent': 'GardenerGrid/1.0 (Open-data importer; GBIF)',
  },
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeId(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 100);
}

function classifyCategory(order, family) {
  const o = (order || '').toLowerCase();
  const f = (family || '').toLowerCase();
  if (o.includes('poales')) return 'Grass';
  if (f.includes('cact')) return 'Succulent';
  if (f.includes('fabaceae')) return 'Herb';
  if (f.includes('asteraceae')) return 'Wildflower';
  if (f.includes('rosaceae')) return 'Shrub';
  return 'Plant';
}

function buildTags(item) {
  const tags = new Set();
  const habitat = String(item.habitat || '').toLowerCase();
  const threat = String(item.threatStatus || '').toLowerCase();
  const life = String(item.lifeForm || '').toLowerCase();

  if (habitat) tags.add(habitat);
  if (life) tags.add(life);
  if (threat) tags.add(threat);

  tags.add('gbif');
  tags.add('open-data');
  return Array.from(tags).filter(Boolean);
}

function toPlantEntry(item, imageAsset) {
  const scientificName = item.scientificName || item.canonicalName || item.species || 'Unknown species';
  const commonName = item.vernacularName || scientificName;
  const family = item.family || 'Unknown family';
  const category = classifyCategory(item.order, family);
  const id = normalizeId(`${scientificName}_${item.key || ''}`) || `plant_${Date.now()}`;

  return {
    id,
    name: commonName,
    scientificName,
    family,
    category,
    tags: buildTags(item),
    description: [
      `${commonName} (${scientificName}) imported from GBIF open-data backbone.`,
      item.rank ? `Taxonomic rank: ${item.rank}.` : null,
      item.order ? `Order: ${item.order}.` : null,
      item.genus ? `Genus: ${item.genus}.` : null,
      item.taxonomicStatus ? `Status: ${item.taxonomicStatus}.` : null,
    ].filter(Boolean).join(' '),
    soilPreference: 'Varies by ecotype and local conditions. Confirm regionally.',
    sunlight: 'Unknown (consult local extension references).',
    water: 'Unknown (species-specific).',
    phMin: 5.5,
    phMax: 7.5,
    hardinessZone: 'Unknown',
    heightCm: 0,
    spreadCm: 0,
    bloomSeason: 'Unknown',
    companionPlants: [],
    pestRepellent: [],
    culinaryUses: 'Unknown',
    medicinalUses: 'Unknown',
    gardeningTips: 'Use region-specific horticultural references for cultivation details.',
    propagation: 'Unknown',
    imageAsset: imageAsset || null,
  };
}

async function fetchMediaUrl(taxonKey) {
  try {
    const res = await client.get('https://api.gbif.org/v1/occurrence/search', {
      params: {
        taxonKey,
        mediaType: 'StillImage',
        limit: 1,
      },
    });

    const row = Array.isArray(res.data?.results) ? res.data.results[0] : null;
    const media = Array.isArray(row?.media) ? row.media[0] : null;
    return media?.identifier || null;
  } catch (_) {
    return null;
  }
}

async function downloadImage(url, filePath) {
  const writer = fs.createWriteStream(filePath);
  const response = await client.get(url, { responseType: 'stream' });
  await new Promise((resolve, reject) => {
    response.data.pipe(writer);
    writer.on('finish', resolve);
    writer.on('error', reject);
  });
}

async function run() {
  console.log(`Building GBIF encyclopedia target=${TARGET}`);

  const plants = [];
  let offset = 0;
  let downloadedCount = 0;

  if (DOWNLOAD_IMAGES) {
    fs.mkdirSync(IMAGE_DIR, { recursive: true });
  }

  while (plants.length < TARGET) {
    const page = await client.get('https://api.gbif.org/v1/species/search', {
      params: {
        kingdomKey: 6,
        rank: 'SPECIES',
        status: 'ACCEPTED',
        limit: PAGE_SIZE,
        offset,
      },
    });

    const rows = Array.isArray(page.data?.results) ? page.data.results : [];
    if (!rows.length) break;

    for (const item of rows) {
      if (plants.length >= TARGET) break;
      if (!item?.scientificName && !item?.canonicalName) continue;

      let imageUrl = null;
      if (INCLUDE_MEDIA && item?.key) {
        imageUrl = await fetchMediaUrl(item.key);
        await sleep(REQUEST_DELAY_MS);
      }

      let imageAsset = imageUrl;
      if (DOWNLOAD_IMAGES && imageUrl && downloadedCount < MAX_IMAGES) {
        try {
          const slug = normalizeId(item.scientificName || item.canonicalName || item.key);
          const fileName = `${slug || `plant_${item.key}`}.jpg`;
          const outPath = path.join(IMAGE_DIR, fileName);
          await downloadImage(imageUrl, outPath);
          imageAsset = `${IMAGE_DIR.replace(/\\/g, '/')}/${fileName}`;
          downloadedCount += 1;
        } catch (_) {
          imageAsset = imageUrl;
        }
      }

      plants.push(toPlantEntry(item, imageAsset));
    }

    offset += PAGE_SIZE;
    console.log(`Fetched ${plants.length} / ${TARGET}`);
    await sleep(REQUEST_DELAY_MS);
  }

  fs.mkdirSync(path.dirname(OUTPUT_FILE), { recursive: true });
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(plants, null, 2));

  console.log(`Done. Wrote ${plants.length} entries to ${OUTPUT_FILE}`);
  if (DOWNLOAD_IMAGES) {
    console.log(`Downloaded ${downloadedCount} images to ${IMAGE_DIR}`);
  }
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
