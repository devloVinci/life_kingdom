// The Warden: the player's hero. Layered parts on a 120x160 canvas.
const { lin, rad, part, p, stroke, ell, inked, composite, sheet, writeRig } = require('./lib');

const W = 120, H = 160;
const steel = () => lin([[0, '#eef2f6'], [0.35, '#aab5c1'], [1, '#4a5563']], 60);
const steelDark = () => lin([[0, '#c9d2dc'], [1, '#4c5664']], 70);
const gold = () => lin([[0, '#ffe08a'], [0.5, '#e0a93a'], [1, '#9a6a1c']], 70);
const blue = () => lin([[0, '#4f7ad1'], [0.6, '#2b4c96'], [1, '#1a2f63']], 75);
const crimson = () => lin([[0, '#8e2b34'], [1, '#4a1219']], 90);
const leather = () => lin([[0, '#7a5434'], [1, '#43291a']], 80);
const skin = () => lin([[0, '#f6d2ae'], [1, '#d39a72']], 70);

const shadow = part(ell(60, 150, 27, 6, '#000', { op: 0.28 }));

const cape = part(
  inked('M43 62 C35 88 30 114 31 136 C46 141 74 141 89 136 C90 114 85 88 77 62 Z', crimson()),
  stroke('M50 80 C47 100 45 118 46 136', '#2d0a10', 1.6, { op: 0.6 }),
  stroke('M70 80 C73 100 75 118 74 136', '#2d0a10', 1.6, { op: 0.6 }),
);

function leg(x, flip) {
  const s = flip ? -1 : 1;
  const cx = x;
  return part(
    inked(`M${cx - 6} 102 L${cx + 6} 102 L${cx + 5} 128 L${cx - 5} 128 Z`, '#3c4350'),
    inked(`M${cx - 6} 125 L${cx + 6} 125 L${cx + 6} 141 L${cx - 6} 141 Z`, steel()),
    p(`M${cx - 6} 125 L${cx + 6} 125 L${cx + 6} 128 L${cx - 6} 128 Z`, '#e7ecf1', { op: 0.6 }),
    inked(
      `M${cx - 7} 139 L${cx + 6} 139 C${cx + 7 + 4 * s} 142 ${cx + 9 * s} 146 ${cx + 9 * s} 150 L${cx - 8} 150 C${cx - 9} 146 ${cx - 9} 142 ${cx - 7} 139 Z`,
      leather(),
    ),
    // knee cop
    inked(`M${cx - 5} 122 C${cx - 5} 116 ${cx + 5} 116 ${cx + 5} 122 C${cx + 5} 127 ${cx - 5} 127 ${cx - 5} 122 Z`, steel(), 1.8),
  );
}
const legL = leg(53, true);
const legR = leg(67, false);

const body = part(
  // breastplate
  inked('M44 64 C41 77 43 92 47 103 L73 103 C77 92 79 77 76 64 C69 59 51 59 44 64 Z', steel()),
  p('M48 66 C46 76 47 86 50 94', 'none'),
  stroke('M60 63 L60 100', '#55606e', 1.2, { op: 0.7 }),
  p('M47 67 C46 74 46 80 48 86 C52 78 54 71 55 64 C52 64 49 65 47 67 Z', '#ffffff', { op: 0.45 }),
  // tabard
  inked('M50 76 L70 76 L72 119 L60 113 L48 119 Z', blue(), 2),
  stroke('M50.5 77 L48.6 118', '#f0c45a', 1.4),
  stroke('M69.5 77 L71.4 118', '#f0c45a', 1.4),
  // emblem: rising sun over a sword
  p('M60 83 L64 91 L60 99 L56 91 Z', gold(), { sw: 1.2 }),
  ell(60, 91, 1.8, 1.8, '#fff3c4'),
  // belt
  inked('M45 98 L75 98 L75 104 L45 104 Z', leather(), 1.8),
  inked('M57 97.5 L63 97.5 L63 104.5 L57 104.5 Z', gold(), 1.4),
  // gorget
  inked('M50 60 C53 56 67 56 70 60 C67 64 53 64 50 60 Z', steelDark(), 1.8),
);

const head = part(
  // neck
  p('M55 52 L65 52 L64 60 L56 60 Z', '#c58c66'),
  // face
  inked('M47.5 35 C47 47 53 55.5 60 55.5 C67 55.5 73 47 72.5 35 Z', skin()),
  p('M66 38 C70 40 72 44 71 48 C69 52 66 54 63 55 C67 50 68 44 66 38 Z', '#b9785a', { op: 0.35 }),
  // eyes, brows, mouth
  ell(54.5, 41.5, 1.5, 2, '#1b1820'),
  ell(65.5, 41.5, 1.5, 2, '#1b1820'),
  ell(54.9, 40.9, 0.5, 0.6, '#fff'),
  ell(65.9, 40.9, 0.5, 0.6, '#fff'),
  stroke('M51 37.6 L57 38.6', '#3a2618', 1.6),
  stroke('M69 37.6 L63 38.6', '#3a2618', 1.6),
  stroke('M57.5 49.5 C59 50.3 61 50.3 62.5 49.5', '#7a3e2c', 1.2),
  stroke('M60 42 L59.3 46 L60.6 46.4', '#a8684a', 1),
  // stubble / jaw shade
  p('M50 47 C53 54 57 55.5 60 55.5 C63 55.5 67 54 70 47 C66 51 54 51 50 47 Z', '#6b4a3a', { op: 0.25 }),
  // plume (behind helmet top)
  inked('M53 18 C57 6 73 2 88 11 C80 11 73 15 68 23 Z', blue(), 2),
  stroke('M58 14 C64 9 72 7 80 9', '#8fb0ee', 1.2, { op: 0.8 }),
  // helmet
  inked('M44 39 C42 22 51 13.5 60 13.5 C69 13.5 78 22 76 39 L72 41 C71 31 66.5 27.5 60 27.5 C53.5 27.5 49 31 48 41 Z', steel()),
  inked('M44 38 L45.5 51 L50 49 L48 40 Z', steelDark(), 1.8),
  inked('M76 38 L74.5 51 L70 49 L72 40 Z', steelDark(), 1.8),
  inked('M58.6 26 L61.4 26 L61.4 41 L58.6 41 Z', steelDark(), 1.4),
  // helmet trim + shine
  stroke('M45 33 C49 25 54 22.5 60 22.5 C66 22.5 71 25 75 33', '#e0a93a', 1.8),
  p('M49 24 C52 18 56 16 60 16 C56 19 53 23 51 29 Z', '#ffffff', { op: 0.6 }),
);

const armL = part(
  // upper arm (mail) + vambrace
  inked('M37 68 L46 68 L45 88 L37 88 Z', '#3c4350'),
  // shield (in front)
  inked('M25 81 L55 81 L55 93 C55 107 47 115 40 119.5 C33 115 25 107 25 93 Z', blue()),
  p('M28 84 L52 84 L52 93 C52 105 46 111 40 115 C34 111 28 105 28 93 Z', 'none', { sw: 1.6, stroke: '#f0c45a' }),
  p('M40 88 L44 97 L40 108 L36 97 Z', gold(), { sw: 1.2 }),
  p('M28 84 L40 84 L40 112 C34 109 28 103 28 93 Z', '#ffffff', { op: 0.12 }),
  // pauldron
  inked('M33 70 C32 61 38 58 44 59 C49 60 50 65 49 70 C45 72 37 73 33 70 Z', steel()),
  stroke('M34 69.5 C39 71.5 44 71 48.5 69.5', '#e0a93a', 1.4),
  p('M36 63 C38 61 41 60.5 43 61 C40 62.5 38 64.5 37 67 Z', '#fff', { op: 0.6 }),
);

const armR = part(
  // sword (held low, blade forward)
  inked('M84.5 105 L89 104 L102 143 L99 146 L96 143 Z', lin([[0, '#ffffff'], [0.5, '#c9d3dd'], [1, '#6f7b89']], 0)),
  stroke('M86.6 106 L99 143', '#ffffff', 0.9, { op: 0.8 }),
  inked('M78 103.5 L93 99 L94 102 L79 106.5 Z', gold(), 1.6),
  inked('M80.5 92 L84 91 L86.5 101 L83 102 Z', leather(), 1.4),
  ell(80.6, 91, 2.6, 2.6, gold(), { sw: 1.4 }),
  // arm + gauntlet
  inked('M74 68 L83 68 L85 88 L77 89 Z', '#3c4350'),
  inked('M76 86 L86 85 L87 98 C85 101 80 101 78 99 Z', steel(), 2),
  // pauldron
  inked('M71 70 C70 65 71 60 76 59 C82 58 88 61 87 70 C83 73 75 72 71 70 Z', steel()),
  stroke('M71.5 69.5 C76 71 81 71.5 86.5 69.5', '#e0a93a', 1.4),
  p('M74 63 C76 61 79 60.5 81 61 C78 62.5 76 64.5 75 67 Z', '#fff', { op: 0.6 }),
);

const rig = {
  name: 'Warden',
  slug: 'warden',
  w: W,
  h: H,
  pivots: {
    shadow: [60, 150],
    cape: [60, 62],
    legL: [53, 104],
    legR: [67, 104],
    body: [60, 104],
    head: [60, 57],
    armL: [42, 66],
    armR: [79, 66],
    root: [60, 150],
  },
  parts: [
    { name: 'Ground Shadow', file: 'ground_shadow.svg', role: 'shadow', art: shadow },
    { name: 'Cape', file: 'cape.svg', role: 'cape', art: cape },
    { name: 'Leg L', file: 'leg_l.svg', role: 'legL', art: legL },
    { name: 'Leg R', file: 'leg_r.svg', role: 'legR', art: legR },
    { name: 'Arm R', file: 'arm_r.svg', role: 'armR', art: armR },
    { name: 'Body', file: 'body.svg', role: 'body', art: body },
    { name: 'Head', file: 'head.svg', role: 'head', art: head },
    { name: 'Arm L', file: 'arm_l.svg', role: 'armL', art: armL },
  ],
};

module.exports = rig;

if (require.main === module) {
  const out = process.argv[2] || 'out';
  const T = Math.PI * 2;
  const frames = [];
  for (let i = 0; i < 4; i++) {
    const s = Math.sin((T * i) / 4);
    frames.push(composite(rig, {
      root: { dy: -2.5 * Math.abs(s) },
      legL: { rot: 0.45 * s }, legR: { rot: -0.45 * s },
      armL: { rot: -0.25 * s }, armR: { rot: -0.3 * s },
      cape: { rot: -0.05 * Math.abs(s), sx: 1 + 0.04 * Math.abs(s) },
    }));
  }
  sheet(`${out}/hero_preview.png`, W, H, [composite(rig), ...frames], { scale: 3 });
  writeRig(`${out}/warden`, rig);
}
