// The dragon companion (facing right). 180x140 canvas, layered parts.
// Skins are colour sets; every skin exports its own folder.
const { lin, part, p, stroke, ell, inked, composite, sheet, writeRig } = require('./lib');

const W = 180, H = 160;
const OFF = 20; // headroom for wings and flight

const SKINS = {
  ember: { hi: '#e2563b', mid: '#b4301f', lo: '#5e140d', belly: ['#ffd88a', '#d08a3b'], wing: ['#a5302a', '#4a0f0c'], horn: ['#f3e6c8', '#8f7c5c'], eye: '#ffd34d', rib: '#e98a6a' },
  frost: { hi: '#8fd3f0', mid: '#3f88b8', lo: '#173c5c', belly: ['#effaff', '#9cc7dc'], wing: ['#5aa3cc', '#16344f'], horn: ['#ffffff', '#9aaebf'], eye: '#bff4ff', rib: '#c9ecfa' },
  verdant: { hi: '#8fce5a', mid: '#3f8a33', lo: '#173a17', belly: ['#f0e6a2', '#b9a85a'], wing: ['#4e9a3c', '#163a14'], horn: ['#efe6c8', '#7d6e4c'], eye: '#ffef6a', rib: '#b5e08c' },
  shadow: { hi: '#6b5a8c', mid: '#3a2c55', lo: '#140e22', belly: ['#b9a3d9', '#6a5590'], wing: ['#4a3670', '#120b20'], horn: ['#d8d0e8', '#6c6280'], eye: '#c86bff', rib: '#9a82c8' },
  gilded: { hi: '#ffe08a', mid: '#d4a02e', lo: '#6d4a0c', belly: ['#fff6d6', '#e3c477'], wing: ['#e0a93a', '#6d4a0c'], horn: ['#ffffff', '#b8a780'], eye: '#ff6b3d', rib: '#fff0b0' },
};

function build(name, c) {
  const scales = () => lin([[0, c.hi], [0.5, c.mid], [1, c.lo]], 70);
  const belly = () => lin([[0, c.belly[0]], [1, c.belly[1]]], 90);
  const wingM = () => lin([[0, c.wing[0]], [1, c.wing[1]]], 60);
  const horn = () => lin([[0, c.horn[0]], [1, c.horn[1]]], 45);
  const dark = c.lo;

  const shadow = part(ell(92, 126, 52, 8, '#000', { op: 0.26 }));

  const wingFar = part(
    inked('M107 69 L113 34 L139 6 C140 19 146 28 157 33 Q141 39 136 49 Q126 55 111 71 Z', lin([[0, c.wing[1]], [1, '#000000']], 60)),
    stroke('M107 69 L113 34 L139 6 M113 34 L157 33 M113 34 L136 49', dark, 1.6),
  );

  const tail = part(
    inked('M66 80 C50 77 35 83 25 91 C19 95 14 95 11 91 C14 98 21 102 30 100 C42 98 54 94 67 97 Z', scales()),
    inked('M12 92 L3 83 L4 97 L13 99 Z', scales(), 1.4),
    stroke('M60 82 C50 81 40 85 32 90', c.hi, 1.2, { op: 0.6 }),
    // tail spikes
    p('M46 80 L49 74 L52 80 Z', horn(), { sw: 1.2 }),
    p('M34 85 L36 79.5 L39.5 84 Z', horn(), { sw: 1.2 }),
  );

  const legsBack = part(
    // far back leg (darker, behind)
    inked('M78 92 C80 102 80 110 82 114 L80 122 L90 122 L90 113 C92 104 90 96 86 90 Z', dark),
    // near back leg (haunch)
    inked('M60 84 C57 99 63 109 69 112 L67 122.5 L80 122.5 L79 112 C85 104 84 93 78 86 Z', scales()),
    p('M66 120 L64 125 L68 123 L70 126 L72 123 L75 126 L76 122 Z', horn(), { sw: 1 }),
    p('M63 90 C62 98 64 104 68 108 C66 100 66 94 68 88 Z', c.hi, { op: 0.45 }),
  );

  const legsFront = part(
    inked('M114 92 L114 122 L124 122 L123 110 C125 103 124 97 121 91 Z', dark),
    inked('M103 91 L101.5 122.5 L113.5 122.5 L113 110 C115 103 115 97 113 90 Z', scales()),
    p('M101 120 L99 125 L103 123 L105 126 L107 123 L110 126 L111 122 Z', horn(), { sw: 1 }),
  );

  const body = part(
    inked('M55 87 C56 75 71 67.5 93 67 C110 66.5 121 71 123.5 81 C126 92 117 101.5 100 103.5 C83 105.5 67 103.5 60 98 C56.5 95 55 91 55 87 Z', scales()),
    p('M67 97.5 C80 103 101 103 117 94.5 C114 99.5 107 103 99 104 C85 105.6 73 103.4 67 97.5 Z', belly()),
    stroke('M76 100.6 L77 103.4 M84 101.6 L84.6 104.6 M92 101.8 L92.2 104.8 M100 101.2 L99.6 104', dark, 0.9, { op: 0.55 }),
    p('M66 78 C70 70 80 67 92 67 C84 70 76 74 70 82 Z', '#ffffff', { op: 0.22 }),
    // back ridge
    p('M70 69 L73 61.5 L77 67.4 Z M80 66.4 L83.5 58.5 L87 65.5 Z M90 65.6 L94 57.5 L97 65.8 Z M100 66.6 L104 59.6 L106.6 68 Z', horn(), { sw: 1.2 }),
  );

  const head = part(
    // neck
    inked('M104 74 C110 60 121 49 133 43 L143 51.5 C133 57.5 125 66 121 81 Z', scales()),
    p('M120.5 80 C124 67 131 59 141 53 L143 51.5 C134 57 127 64 123.5 76 Z', belly()),
    p('M111 63 L113.5 56 L117 61 Z M118 56 L121 49.5 L124 54.6 Z', horn(), { sw: 1.1 }),
    // horns
    inked('M135.5 34.5 C129 26 122 21 114 18.5 C120 25 125 32 130 39 Z', horn(), 1.4),
    inked('M142 31 C139 24 134 18.5 128 15 C131 21 134 27 137 33 Z', horn(), 1.4),
    // skull + snout
    inked('M128 41 C131 30 144 27 153 31 L166.5 37 C171 39.5 171 46 166.5 48 L153 52.5 C144 56.5 134 54 130 50 Z', scales()),
    p('M131 47 C138 52 148 52.5 156 50 L166 47.4 C164 49.4 160 50.4 153 52.5 C144 56 135 54 131 47 Z', dark, { op: 0.45 }),
    stroke('M151 46.6 C156 46.2 161 45.6 165.5 44.6', dark, 1.3),
    p('M134 35 C138 31 144 30 150 31.4 C144 33 139 35 136 39 Z', '#ffffff', { op: 0.3 }),
    // eye
    p('M141.5 37.4 C143.5 35 148 35 150 37.4 C148 40 143.5 40 141.5 37.4 Z', c.eye, { sw: 1.2 }),
    ell(146, 37.4, 0.9, 2, '#14100c'),
    stroke('M140 34.2 C143.5 32.6 148 32.4 152 34', dark, 2),
    ell(164.2, 40.3, 1.1, 0.8, '#14100c'),
    // teeth
    p('M155 47.6 L156.4 50.6 L157.8 47.2 Z M159.6 46.8 L160.8 49.4 L162 46.4 Z', '#fff8e8', { sw: 0.6 }),
  );

  const wingNear = part(
    inked('M116 6 C92 2 66 0 44 8 Q66 22 56 35 Q76 42 71 57 Q86 58 93 71 L88 36 Z', wingM()),
    p('M88 36 L44 8 Q66 22 56 35 Z', '#000000', { op: 0.12 }),
    p('M88 36 L71 57 Q86 58 93 71 Z', '#ffffff', { op: 0.08 }),
    stroke('M88 36 L44 8 M88 36 L56 35 M88 36 L71 57', c.rib, 1.3, { op: 0.85 }),
    stroke('M93 71 L88 36 L116 6', dark, 2.6),
    p('M116 6 L121 2 L119 8 Z', horn(), { sw: 1 }),
    ell(88, 36, 2.6, 2.6, horn(), { sw: 1 }),
  );

  const shift = (a) => ({ defs: a.defs, body: `<g transform="translate(0 ${OFF})">${a.body}</g>` });
  const parts = { shadow, wingFar, tail, legsBack, legsFront, body, head, wingNear };
  for (const k of Object.keys(parts)) parts[k] = shift(parts[k]);
  const pv = (x, y) => [x, y + OFF];
  return {
    name: `Dragon (${name})`,
    slug: `dragon_${name}`,
    w: W,
    h: H,
    pivots: {
      shadow: pv(92, 126),
      wingR: pv(107, 68),
      tail: pv(64, 88),
      legR: pv(74, 92),
      legL: pv(110, 92),
      body: pv(92, 106),
      head: pv(112, 74),
      wingL: pv(94, 70),
      root: pv(92, 122),
    },
    parts: [
      { name: 'Ground Shadow', file: 'ground_shadow.svg', role: 'shadow', art: parts.shadow },
      { name: 'Wing Far', file: 'wing_far.svg', role: 'wingR', art: parts.wingFar },
      { name: 'Tail', file: 'tail.svg', role: 'tail', art: parts.tail },
      { name: 'Back Legs', file: 'legs_back.svg', role: 'legR', art: parts.legsBack },
      { name: 'Front Legs', file: 'legs_front.svg', role: 'legL', art: parts.legsFront },
      { name: 'Body', file: 'body.svg', role: 'body', art: parts.body },
      { name: 'Head', file: 'head.svg', role: 'head', art: parts.head },
      { name: 'Wing Near', file: 'wing_near.svg', role: 'wingL', art: parts.wingNear },
    ],
  };
}

module.exports = { SKINS, build };

if (require.main === module) {
  const out = process.argv[2] || 'out';
  const rigs = Object.entries(SKINS).map(([k, c]) => build(k, c));
  const T = Math.PI * 2;
  const ember = rigs[0];
  const frames = [composite(ember)];
  for (let i = 0; i < 4; i++) {
    const s = Math.sin((T * i) / 4);
    frames.push(composite(ember, {
      root: { dy: -18 + 4 * s },
      wingL: { rot: -0.35 * s, sy: 1 - 0.45 * s },
      wingR: { sy: 1 - 0.45 * s },
      legL: { rot: -0.5 }, legR: { rot: 0.45 },
      tail: { rot: 0.12 * s },
      shadow: { sx: 0.7, sy: 0.7 },
    }));
  }
  sheet(`${out}/dragon_preview.png`, W, H, frames, { scale: 2.2 });
  sheet(`${out}/dragon_skins.png`, W, H, rigs.map((r) => composite(r)), { scale: 2 });
  for (const r of rigs) writeRig(`${out}/${r.slug}`, r);
}
