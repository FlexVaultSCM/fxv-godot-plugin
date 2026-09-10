const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');

// 1. Read addons/flexvault/plugin.cfg
const pluginCfgPath = path.join(repoRoot, 'addons', 'flexvault', 'plugin.cfg');
if (!fs.existsSync(pluginCfgPath)) {
  console.error('Error: plugin.cfg file not found at ' + pluginCfgPath);
  process.exit(1);
}

const pluginCfg = fs.readFileSync(pluginCfgPath, 'utf8');
const versionMatch = pluginCfg.match(/version\s*=\s*"([^"]+)"/);
if (!versionMatch) {
  console.error('Error: addons/flexvault/plugin.cfg missing version field.');
  process.exit(1);
}

const pluginVersion = versionMatch[1];
const semverRegex = /^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/;
if (!semverRegex.test(pluginVersion)) {
  console.error(`Error: plugin.cfg version '${pluginVersion}' is not a valid semantic version.`);
  process.exit(1);
}

console.log(`[Version Check] addons/flexvault/plugin.cfg version: ${pluginVersion}`);

// 2. Validate .github/release-please-manifest.json
const manifestPath = path.join(repoRoot, '.github', 'release-please-manifest.json');
if (fs.existsSync(manifestPath)) {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  const manifestVersion = manifest['.'];
  if (manifestVersion && manifestVersion !== pluginVersion) {
    console.error(`Error: Release manifest version (${manifestVersion}) does not match plugin.cfg version (${pluginVersion}).`);
    process.exit(1);
  }
  console.log(`[Version Check] release manifest version matches: ${manifestVersion}`);
}

// 3. If --tag argument is provided, validate git release tag matches package version
const tagIndex = process.argv.indexOf('--tag');
if (tagIndex !== -1 && tagIndex + 1 < process.argv.length) {
  const tag = process.argv[tagIndex + 1];
  const cleanTag = tag.replace(/^v/, '');
  if (cleanTag !== pluginVersion) {
    console.error(`Error: Release tag '${tag}' (${cleanTag}) does not match plugin.cfg version (${pluginVersion})!`);
    process.exit(1);
  }
  console.log(`[Version Check] Release tag matches plugin.cfg version: ${tag} == ${pluginVersion}`);
}

console.log('All version checks passed successfully.');
