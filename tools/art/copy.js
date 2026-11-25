// Copies generated art into the Flutter assets folder.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..', '..', 'assets');
const cp = (src, dst) => { fs.mkdirSync(dst, { recursive: true }); for (const f of fs.readdirSync(src)) fs.copyFileSync(path.join(src, f), path.join(dst, f)); };
cp('out/warden', path.join(root, 'characters', 'warden'));
for (const s of ['ember', 'frost', 'verdant', 'shadow', 'gilded']) cp(`out/dragon_${s}`, path.join(root, 'characters', `dragon_${s}`));
cp('out/buildings', path.join(root, 'buildings'));
console.log('copied');
