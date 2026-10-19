const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');

// 1. Read plugin version from addons/flexvault/plugin.cfg
const pluginCfgPath = path.join(repoRoot, 'addons', 'flexvault', 'plugin.cfg');
if (!fs.existsSync(pluginCfgPath)) {
  console.error('Error: plugin.cfg not found at ' + pluginCfgPath);
  process.exit(1);
}
const pluginCfg = fs.readFileSync(pluginCfgPath, 'utf8');
const versionMatch = pluginCfg.match(/version\s*=\s*"([^"]+)"/);
if (!versionMatch) {
  console.error('Error: missing version in ' + pluginCfgPath);
  process.exit(1);
}
const pluginVersion = versionMatch[1];

// 2. Read CLI compatibility range from addons/flexvault/core/fxv_version_guard.gd
const guardPath = path.join(repoRoot, 'addons', 'flexvault', 'core', 'fxv_version_guard.gd');
if (!fs.existsSync(guardPath)) {
  console.error('Error: fxv_version_guard.gd not found at ' + guardPath);
  process.exit(1);
}
const guardContent = fs.readFileSync(guardPath, 'utf8');

const minMajorMatch = guardContent.match(/const\s+MIN_MAJOR(?::\s*int)?\s*=\s*(\d+)/);
const minMinorMatch = guardContent.match(/const\s+MIN_MINOR(?::\s*int)?\s*=\s*(\d+)/);
const minPatchMatch = guardContent.match(/const\s+MIN_PATCH(?::\s*int)?\s*=\s*(\d+)/);

const maxMajorMatch = guardContent.match(/const\s+MAX_MAJOR(?::\s*int)?\s*=\s*(\d+)/);
const maxMinorMatch = guardContent.match(/const\s+MAX_MINOR(?::\s*int)?\s*=\s*(\d+)/);
const maxPatchMatch = guardContent.match(/const\s+MAX_PATCH(?::\s*int)?\s*=\s*(\d+)/);

if (!minMajorMatch || !minMinorMatch || !minPatchMatch || !maxMajorMatch || !maxMinorMatch || !maxPatchMatch) {
  console.error('Error: Could not parse FxvVersionGuard MIN/MAX constants from ' + guardPath);
  process.exit(1);
}

const cliMin = `${minMajorMatch[1]}.${minMinorMatch[1]}.${minPatchMatch[1]}`;
const cliMax = `${maxMajorMatch[1]}.${maxMinorMatch[1]}.${maxPatchMatch[1]}`;

// 3. Resolve tag and clean version
let tag = process.env.RELEASE_TAG || `v${pluginVersion}`;
const tagArgIndex = process.argv.indexOf('--tag');
if (tagArgIndex !== -1 && tagArgIndex + 1 < process.argv.length) {
  tag = process.argv[tagArgIndex + 1];
}
const cleanVersion = tag.replace(/^v/, '');

const outputPath = path.join(repoRoot, 'version.json');
const manifest = {
  name: 'godot',
  plugin_version: cleanVersion,
  tag: tag,
  cli_compatibility: {
    min: cliMin,
    max: cliMax
  },
  assets: {
    plugin_zip: `fxv-godot-plugin-${cleanVersion}.zip`,
    plugin_zip_latest: 'fxv-godot-plugin.zip'
  }
};

fs.writeFileSync(outputPath, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
console.log(`Generated ${outputPath}:`);
console.log(JSON.stringify(manifest, null, 2));
