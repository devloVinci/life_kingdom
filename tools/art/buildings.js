// Kingdom buildings, 3/4 view, light from the top-left.
// Each building: <id>.svg (full art) and <id>_snow.svg (snow caps for winter).
const fs = require('fs');
const { lin, rad, part, p, stroke, ell, inked, svgDoc, sheet } = require('./lib');

const M = {
  stone: () => lin([[0, '#efe6d6'], [0.45, '#c3b59c'], [1, '#857761']], 20),
  stoneDark: () => lin([[0, '#a69780'], [1, '#5f5446']], 20),
  stoneTop: () => lin([[0, '#f7f0e2'], [1, '#d4c8b1']], 90),
  blue: () => lin([[0, '#6f97e2'], [0.5, '#34579f'], [1, '#1b2f66']], 20),
  red: () => lin([[0, '#ec7558'], [0.5, '#b03b2d'], [1, '#5c1914']], 20),
  slate: () => lin([[0, '#7f8a9e'], [0.5, '#4d566a'], [1, '#262c3a']], 20),
  thatch: () => lin([[0, '#f0c67a'], [0.5, '#c08a3e'], [1, '#6e4719']], 20),
  wood: () => lin([[0, '#b37c46'], [1, '#5e3b1d']], 20),
  woodV: () => lin([[0, '#9c6a3a'], [1, '#4f3118']], 90),
  gold: () => lin([[0, '#fff0a8'], [0.45, '#e9b443'], [1, '#8f5f16']], 30),
  copper: () => lin([[0, '#9fe0c8'], [0.5, '#4f9e86'], [1, '#1f4d44']], 20),
  canvas: () => lin([[0, '#fbf3e1'], [0.6, '#d9cbae'], [1, '#9b8b6d']], 20),
  glow: () => lin([[0, '#fff6c2'], [0.5, '#ffc04d'], [1, '#d8761a']], 90),
  arcane: () => lin([[0, '#f2d6ff'], [0.5, '#b26bff'], [1, '#5a1fa8']], 90),
};
const SNOW = () => lin([[0, '#ffffff'], [1, '#d6e6f5']], 90);

/** Stone wall: face + staggered block lines + soft left light. */
function wall(x, y, w, h, mat = M.stone, row = 9) {
  const out = [inked(`M${x} ${y} L${x + w} ${y} L${x + w} ${y + h} L${x} ${y + h} Z`, mat())];
  const lines = [];
  for (let yy = y + row, r = 0; yy < y + h - 2; yy += row, r++) {
    lines.push(`M${x + 1.5} ${yy} L${x + w - 1.5} ${yy}`);
    const off = r % 2 ? 7 : 0;
    for (let xx = x + 6 + off; xx < x + w - 3; xx += 14) lines.push(`M${xx} ${yy} L${xx} ${Math.min(yy + row, y + h - 1)}`);
  }
  out.push(stroke(lines.join(' '), '#5b4f40', 0.9, { op: 0.35 }));
  out.push(p(`M${x + 1} ${y + 1} L${x + w * 0.22} ${y + 1} L${x + w * 0.22} ${y + h - 1} L${x + 1} ${y + h - 1} Z`, '#ffffff', { op: 0.16 }));
  out.push(p(`M${x + w * 0.78} ${y + 1} L${x + w - 1} ${y + 1} L${x + w - 1} ${y + h - 1} L${x + w * 0.78} ${y + h - 1} Z`, '#000000', { op: 0.14 }));
  return out;
}

function battlements(x, y, w, n, mat = M.stone) {
  const out = [];
  const mw = w / (2 * n - 1);
  for (let i = 0; i < n; i++) {
    const xx = x + i * 2 * mw;
    out.push(inked(`M${xx} ${y - 7} L${xx + mw} ${y - 7} L${xx + mw} ${y + 1} L${xx} ${y + 1} Z`, mat()));
    out.push(p(`M${xx + 0.8} ${y - 6.2} L${xx + mw - 0.8} ${y - 6.2} L${xx + mw - 0.8} ${y - 4.6} L${xx + 0.8} ${y - 4.6} Z`, '#ffffff', { op: 0.4 }));
  }
  return out;
}

/** Cone roof sitting on a round tower top. */
function cone(cx, by, r, h, mat) {
  return [
    inked(`M${cx - r} ${by} Q${cx} ${by + r * 0.42} ${cx + r} ${by} L${cx} ${by - h} Z`, mat()),
    p(`M${cx - r + 2} ${by} Q${cx - r * 0.4} ${by + r * 0.3} ${cx - 2} ${by + r * 0.36} L${cx} ${by - h + 4} Z`, '#ffffff', { op: 0.16 }),
    p(`M${cx + 2} ${by + r * 0.36} Q${cx + r * 0.6} ${by + r * 0.26} ${cx + r - 2} ${by} L${cx} ${by - h + 4} Z`, '#000000', { op: 0.18 }),
    stroke(`M${cx - r * 0.66} ${by - h * 0.32 + 2} Q${cx} ${by - h * 0.32 + r * 0.3} ${cx + r * 0.66} ${by - h * 0.32 + 2}`, '#000', 1, { op: 0.25 }),
    stroke(`M${cx - r * 0.86} ${by - h * 0.12 + 1} Q${cx} ${by - h * 0.12 + r * 0.38} ${cx + r * 0.86} ${by - h * 0.12 + 1}`, '#000', 1, { op: 0.2 }),
  ];
}
function coneSnow(cx, by, r, h) {
  return inked(`M${cx - r * 0.42} ${by - h * 0.58} Q${cx - r * 0.2} ${by - h * 0.5} ${cx} ${by - h * 0.55} Q${cx + r * 0.22} ${by - h * 0.48} ${cx + r * 0.42} ${by - h * 0.58} L${cx} ${by - h + 1} Z`, SNOW(), 1.2);
}

/** Gable roof: front triangle face + side slope. */
function gable(x, y, w, h, mat, depth = 14) {
  const cx = x + w / 2;
  const up = depth * 0.6;
  return [
    inked(`M${cx} ${y - h} L${cx + depth} ${y - h - up} L${x + w + depth + 4} ${y + 2 - up} L${x + w + 4} ${y + 2} Z`, mat()),
    p(`M${cx} ${y - h} L${cx + depth} ${y - h - up} L${x + w + depth + 4} ${y + 2 - up} L${x + w + 4} ${y + 2} Z`, '#000', { op: 0.18 }),
    inked(`M${x - 4} ${y + 2} L${cx} ${y - h} L${x + w + 4} ${y + 2} Z`, mat()),
    p(`M${x + 2} ${y} L${cx} ${y - h + 6} L${cx} ${y} Z`, '#ffffff', { op: 0.14 }),
  ];
}

function windowArch(x, y, w, h, glow = M.glow) {
  return [
    inked(`M${x} ${y + h} L${x} ${y + w / 2} A${w / 2} ${w / 2} 0 0 1 ${x + w} ${y + w / 2} L${x + w} ${y + h} Z`, glow(), 1.3),
    stroke(`M${x + w / 2} ${y + 1} L${x + w / 2} ${y + h}`, '#5b3a17', 0.9, { op: 0.8 }),
    stroke(`M${x} ${y + h * 0.6} L${x + w} ${y + h * 0.6}`, '#5b3a17', 0.9, { op: 0.8 }),
  ];
}

function door(x, y, w, h) {
  const lines = [];
  for (let xx = x + w / 4; xx < x + w - 1; xx += w / 4) lines.push(`M${xx} ${y + 3} L${xx} ${y + h}`);
  return [
    inked(`M${x} ${y + h} L${x} ${y + w / 2} A${w / 2} ${w / 2} 0 0 1 ${x + w} ${y + w / 2} L${x + w} ${y + h} Z`, M.woodV(), 1.5),
    stroke(lines.join(' '), '#2c1a0b', 0.9, { op: 0.6 }),
    stroke(`M${x + 1} ${y + h * 0.55} L${x + w - 1} ${y + h * 0.55}`, '#2a2a30', 1.6),
    ell(x + w * 0.72, y + h * 0.66, 1.2, 1.2, M.gold()),
  ];
}

function flag(x, y, color, len = 16) {
  return [
    stroke(`M${x} ${y} L${x} ${y - 20}`, '#3a2a1a', 1.6),
    inked(`M${x} ${y - 20} C${x + len * 0.5} ${y - 23} ${x + len * 0.7} ${y - 16} ${x + len} ${y - 18} L${x + len - 4} ${y - 13} L${x + len} ${y - 8} C${x + len * 0.6} ${y - 6} ${x + len * 0.4} ${y - 12} ${x} ${y - 10} Z`, color, 1.2),
  ];
}

function banner(x, y, w, h, mat) {
  return [
    inked(`M${x} ${y} L${x + w} ${y} L${x + w} ${y + h} L${x + w / 2} ${y + h - 6} L${x} ${y + h} Z`, mat(), 1.3),
    p(`M${x + w / 2} ${y + 6} L${x + w / 2 + 4} ${y + 12} L${x + w / 2} ${y + 18} L${x + w / 2 - 4} ${y + 12} Z`, M.gold(), { sw: 0.8 }),
    stroke(`M${x - 2} ${y} L${x + w + 2} ${y}`, '#3a2a1a', 2),
  ];
}

function foundation(cx, by, rx, ry) {
  return [
    ell(cx, by + 2, rx + 6, ry + 4, '#000', { op: 0.22 }),
    inked(`M${cx - rx} ${by} Q${cx} ${by + ry * 2} ${cx + rx} ${by} L${cx + rx} ${by - 5} L${cx - rx} ${by - 5} Z`, M.stoneDark(), 1.4),
  ];
}

// ---------------------------------------------------------------------------

const B = {};

B.keep = {
  w: 200, h: 210, anchor: [100, 200],
  art: () => [
    foundation(100, 194, 86, 8),
    // rear keep tower
    wall(74, 72, 52, 104),
    windowArch(91, 84, 18, 22),
    ...cone(100, 74, 33, 58, M.blue),
    flag(100, 18, M.blue()),
    // side towers
    wall(18, 104, 40, 80),
    windowArch(31, 120, 13, 16),
    ...cone(38, 105, 25, 42, M.blue),
    wall(142, 104, 40, 80),
    windowArch(155, 120, 13, 16),
    ...cone(162, 105, 25, 42, M.blue),
    // curtain wall + gate
    wall(50, 132, 100, 58),
    battlements(50, 132, 100, 7),
    inked('M82 190 L82 160 A18 18 0 0 1 118 160 L118 190 Z', '#2a2230', 1.6),
    stroke('M86 160 L86 190 M92 152 L92 190 M100 150 L100 190 M108 152 L108 190 M114 160 L114 190 M84 166 L116 166 M84 176 L116 176', '#8a8f9a', 1.4),
    p('M80 190 L80 160 A20 20 0 0 1 120 160 L120 190 L117 190 L117 160 A17 17 0 0 0 83 160 L83 190 Z', M.stoneDark(), { sw: 1.2 }),
    banner(58, 140, 14, 30, M.blue),
    banner(128, 140, 14, 30, M.blue),
  ],
  snow: () => [coneSnow(100, 74, 33, 58), coneSnow(38, 105, 25, 42), coneSnow(162, 105, 25, 42),
    ...[0, 1, 2, 3, 4, 5, 6].map((i) => p(`M${50 + i * 14.3 - 1} ${125} Q${50 + i * 14.3 + 7} ${121} ${50 + i * 14.3 + 15.3} ${125} Z`, '#fff')),
  ],
};

B.builders_hut = {
  w: 140, h: 130, anchor: [66, 122],
  art: () => [
    foundation(64, 118, 50, 6),
    // chimney (behind roof)
    wall(86, 30, 12, 24, M.stoneDark, 7),
    // walls
    inked('M22 72 L104 72 L104 116 L22 116 Z', M.wood()),
    stroke('M22 84 L104 84 M22 96 L104 96 M22 108 L104 108', '#3a240f', 1, { op: 0.5 }),
    inked('M104 72 L120 62 L120 106 L104 116 Z', M.woodV()),
    stroke('M22 72 L22 116 M63 72 L63 116 M104 72 L104 116', '#3a240f', 3),
    door(53, 90, 20, 26),
    windowArch(31, 86, 14, 14),
    windowArch(82, 86, 14, 14),
    // roof
    ...gable(18, 74, 90, 48, M.thatch, 16),
    stroke('M30 66 L63 32 M44 66 L63 44 M82 66 L63 46 M96 66 L63 34', '#6e4719', 1, { op: 0.45 }),
    // crates + barrel
    inked('M108 104 L124 104 L124 120 L108 120 Z', M.wood(), 1.3),
    stroke('M108 104 L124 120 M124 104 L108 120', '#3a240f', 1, { op: 0.6 }),
    inked('M8 102 C8 98 20 98 20 102 L20 118 C20 122 8 122 8 118 Z', M.woodV(), 1.3),
    stroke('M8 107 L20 107 M8 114 L20 114', '#2a2a30', 1.4),
    // hammer sign
    stroke('M40 66 L40 58', '#3a240f', 1.6),
    inked('M34 52 L48 52 L48 58 L34 58 Z', M.wood(), 1.1),
    stroke('M37 55 L45 55', '#efe2c4', 1.6),
  ],
  snow: () => [inked('M14 77 L63 25 L112 77 L104 74 L63 34 L22 74 Z', SNOW(), 1.2), inked('M63 26 L79 16 L124 58 L110 66 Z', SNOW(), 1.2), p('M86 30 Q92 25 98 30 Z', '#fff')],
};

B.army_camp = {
  w: 160, h: 120, anchor: [80, 110],
  art: () => [
    ell(80, 100, 72, 14, '#000', { op: 0.16 }),
    // palisade (back)
    ...Array.from({ length: 13 }, (_, i) => inked(`M${14 + i * 10} 76 L${14 + i * 10} 50 L${19 + i * 10} 44 L${24 + i * 10} 50 L${24 + i * 10} 76 Z`, M.wood(), 1.1)),
    stroke('M12 58 L148 58 M12 70 L148 70', '#3a240f', 2),
    // tents
    inked('M18 100 L42 56 L66 100 Z', M.canvas(), 1.6),
    inked('M42 56 L42 100 L52 100 Z', '#7e6e52', 1),
    flag(42, 58, M.red(), 14),
    inked('M94 100 L118 56 L142 100 Z', M.canvas(), 1.6),
    inked('M118 56 L118 100 L128 100 Z', '#7e6e52', 1),
    flag(118, 58, M.blue(), 14),
    // campfire
    ell(80, 102, 14, 5, '#3b3b42'),
    stroke('M70 102 L90 96 M70 96 L90 102', '#5e3b1d', 3),
    p('M74 98 C74 88 80 84 80 76 C84 84 88 88 86 98 C84 101 76 101 74 98 Z', M.glow(), { sw: 1 }),
    p('M78 98 C78 93 80 91 80 87 C82 91 83 94 82 98 Z', '#fff6c2'),
    // weapon rack
    stroke('M60 86 L60 104 M66 86 L66 104 M56 92 L70 92', '#5e3b1d', 2),
    stroke('M58 82 L58 98 M63 80 L63 96 M68 82 L68 98', '#c9d3dd', 1.6),
  ],
  snow: () => [p('M30 78 L42 56 L54 78 Q42 72 30 78 Z', '#fff'), p('M106 78 L118 56 L130 78 Q118 72 106 78 Z', '#fff')],
};

B.laboratory = {
  w: 120, h: 170, anchor: [60, 162],
  art: () => [
    foundation(60, 158, 40, 6),
    // pipes
    inked('M86 70 L94 70 L94 30 L100 30 L100 22 L88 22 L88 30 Z', M.copper(), 1.3),
    p('M90 22 C88 14 96 12 94 6 C100 10 98 16 100 22 Z', '#cfc7e8', { op: 0.6 }),
    // tower
    wall(26, 76, 68, 82),
    inked('M94 76 L104 82 L104 152 L94 158 Z', M.stoneDark()),
    windowArch(37, 92, 14, 22, M.arcane),
    windowArch(69, 92, 14, 22, M.arcane),
    door(50, 128, 20, 30),
    // dome
    inked('M20 78 C20 50 38 38 60 38 C82 38 100 50 100 78 Z', M.copper()),
    stroke('M60 38 L60 78 M40 44 C36 56 34 66 34 78 M80 44 C84 56 86 66 86 78', '#1f4d44', 1.1, { op: 0.6 }),
    p('M28 70 C28 54 40 44 54 42 C44 50 38 60 36 74 Z', '#ffffff', { op: 0.3 }),
    inked('M16 76 L104 76 L104 82 L16 82 Z', M.stoneTop(), 1.4),
    // orb
    stroke('M60 38 L60 26', '#3a2a1a', 1.6),
    ell(60, 22, 6, 6, M.arcane(), { sw: 1.4 }),
    ell(58, 20, 2, 2, '#fff', { op: 0.8 }),
  ],
  snow: () => [inked('M26 60 C30 48 44 40 60 40 C76 40 90 48 94 60 C84 54 72 52 60 54 C48 52 36 54 26 60 Z', SNOW(), 1.2), p('M16 75 L104 75 L102 72 L18 72 Z', '#fff')],
};

B.treasury = {
  w: 150, h: 140, anchor: [72, 132],
  art: () => [
    foundation(72, 128, 58, 7),
    wall(20, 72, 104, 56),
    inked('M124 72 L136 78 L136 122 L124 128 Z', M.stoneDark()),
    // columns
    ...[30, 54, 90, 114].map((x) => [inked(`M${x - 4} 76 L${x + 4} 76 L${x + 4} 126 L${x - 4} 126 Z`, M.stoneTop(), 1.2), stroke(`M${x - 1.5} 79 L${x - 1.5} 123`, '#ffffff', 1, { op: 0.5 })]),
    door(62, 96, 20, 32),
    p('M60 92 L84 92 L84 96 L60 96 Z', M.gold(), { sw: 1 }),
    // pediment + dome
    inked('M14 74 L130 74 L130 66 L14 66 Z', M.stoneTop()),
    inked('M34 66 C34 36 52 24 72 24 C92 24 110 36 110 66 Z', M.gold()),
    stroke('M72 24 L72 66 M52 30 C48 42 46 54 46 66 M92 30 C96 42 98 54 98 66', '#8f5f16', 1.1, { op: 0.6 }),
    p('M42 60 C42 44 52 32 64 28 C56 36 50 46 48 60 Z', '#fff', { op: 0.45 }),
    ell(72, 20, 5, 5, M.gold(), { sw: 1.4 }),
    // coins + bags
    ...[[18, 126], [26, 128], [22, 122], [122, 128], [130, 126]].map(([x, y]) => ell(x, y, 5, 2.4, M.gold(), { sw: 1 })),
    inked('M106 112 C102 120 104 128 112 128 C120 128 122 120 118 112 L115 109 L109 109 Z', M.canvas(), 1.2),
    stroke('M109 110 L115 110', '#7a5a2a', 1.6),
  ],
  snow: () => [inked('M42 46 C48 32 60 26 72 26 C84 26 96 32 102 46 C92 40 82 38 72 40 C62 38 52 40 42 46 Z', SNOW(), 1.2), p('M14 66 L130 66 L128 62 L16 62 Z', '#fff')],
};

B.clan_castle = {
  w: 160, h: 150, anchor: [78, 142],
  art: () => [
    foundation(78, 138, 64, 7),
    wall(22, 72, 112, 66),
    inked('M134 72 L146 78 L146 132 L134 138 Z', M.stoneDark()),
    battlements(22, 72, 112, 8),
    // hall roof behind battlements
    inked('M36 64 L78 30 L120 64 Z', M.red()),
    p('M40 63 L78 34 L78 63 Z', '#fff', { op: 0.14 }),
    flag(78, 32, M.red(), 18),
    windowArch(36, 90, 14, 20),
    windowArch(106, 90, 14, 20),
    door(66, 102, 24, 36),
    // shields on wall
    ...[[56, 96], [118, 120]].map(([x, y]) => inked(`M${x - 6} ${y - 6} L${x + 6} ${y - 6} L${x + 6} ${y + 1} C${x + 6} ${y + 6} ${x} ${y + 9} ${x} ${y + 9} C${x} ${y + 9} ${x - 6} ${y + 6} ${x - 6} ${y + 1} Z`, M.red(), 1.2)),
    banner(92, 80, 12, 26, M.red),
  ],
  snow: () => [inked('M50 50 L78 30 L106 50 Q92 46 78 48 Q64 46 50 50 Z', SNOW(), 1.2)],
};

B.shop = {
  w: 150, h: 130, anchor: [70, 122],
  art: () => [
    foundation(70, 118, 56, 6),
    // stall body
    inked('M22 82 L118 82 L118 116 L22 116 Z', M.wood()),
    stroke('M22 94 L118 94 M22 106 L118 106', '#3a240f', 1, { op: 0.5 }),
    inked('M18 80 L122 80 L122 88 L18 88 Z', M.woodV(), 1.4),
    // goods on counter
    ...[[32, 'blue'], [48, 'red'], [64, 'gold'], [80, 'copper'], [96, 'arcane']].map(([x, m]) => ell(x, 77, 5.5, 4.5, M[m](), { sw: 1.1 })),
    ell(108, 77, 4, 3.5, M.glow(), { sw: 1.1 }),
    // posts
    stroke('M24 44 L24 116 M116 44 L116 116', '#4f3118', 4),
    // striped awning
    inked('M12 48 L128 48 L136 66 L4 66 Z', '#f4ecd8'),
    ...[0, 2, 4, 6, 8, 10].map((i) => p(`M${12 + i * 9.7} 48 L${21.7 + i * 9.7} 48 L${4 + (i + 1) * 12} 66 L${4 + i * 12} 66 Z`, '#c8402f')),
    p('M4 66 L136 66 L136 66', 'none', { sw: 1.6 }),
    ...Array.from({ length: 11 }, (_, i) => inked(`M${4 + i * 12} 66 Q${10 + i * 12} 74 ${16 + i * 12} 66 Z`, i % 2 ? '#c8402f' : '#f4ecd8', 1.1)),
    // sign
    stroke('M70 48 L70 40', '#3a240f', 1.6),
    inked('M52 22 L88 22 L88 40 L52 40 Z', M.wood(), 1.4),
    ell(70, 31, 6, 6, M.gold(), { sw: 1.2 }),
    // barrels
    inked('M124 98 C124 94 138 94 138 98 L138 116 C138 120 124 120 124 116 Z', M.woodV(), 1.3),
    stroke('M124 104 L138 104 M124 111 L138 111', '#2a2a30', 1.4),
  ],
  snow: () => [inked('M12 48 L128 48 L130 52 Q70 46 10 52 Z', SNOW(), 1.2), p('M52 22 L88 22 L88 19 L52 19 Z', '#fff')],
};

B.magic_items = {
  w: 120, h: 150, anchor: [60, 142],
  art: () => [
    foundation(60, 138, 44, 7),
    // stone circle base
    inked('M18 132 L102 132 L98 120 L22 120 Z', M.stoneTop(), 1.4),
    // pillars + arch
    wall(24, 64, 16, 56, M.stone, 8),
    wall(80, 64, 16, 56, M.stone, 8),
    inked('M20 66 C24 34 42 22 60 22 C78 22 96 34 100 66 L84 66 C82 46 72 38 60 38 C48 38 38 46 36 66 Z', M.stone()),
    stroke('M30 40 L38 46 M46 28 L50 37 M60 24 L60 36 M74 28 L70 37 M90 40 L82 46', '#5b4f40', 1, { op: 0.45 }),
    ell(60, 24, 5, 5, M.arcane(), { sw: 1.2 }),
    // floating crystal with halo
    ell(60, 78, 22, 22, '#b26bff', { op: 0.18 }),
    ell(60, 78, 13, 13, '#e2b8ff', { op: 0.25 }),
    inked('M60 58 L71 76 L60 100 L49 76 Z', M.arcane(), 1.4),
    p('M60 58 L60 100 L49 76 Z', '#ffffff', { op: 0.25 }),
    // runes
    ...[[30, 126], [46, 128], [74, 128], [90, 126]].map(([x, y]) => stroke(`M${x - 3} ${y} L${x} ${y - 4} L${x + 3} ${y}`, '#b26bff', 1.4)),
  ],
  snow: () => [inked('M26 42 C34 30 46 23 60 23 C74 23 86 30 94 42 C84 36 72 34 60 35 C48 34 36 36 26 42 Z', SNOW(), 1.2), p('M18 120 L102 120 L100 117 L20 117 Z', '#fff')],
};

module.exports = B;

if (require.main === module) {
  const out = process.argv[2] || 'out/buildings';
  fs.mkdirSync(out, { recursive: true });
  const frames = [];
  const snowFrames = [];
  const meta = {};
  for (const [id, b] of Object.entries(B)) {
    const art = part(b.art());
    const snow = part(b.snow());
    fs.writeFileSync(`${out}/${id}.svg`, svgDoc(b.w, b.h, [art]));
    fs.writeFileSync(`${out}/${id}_snow.svg`, svgDoc(b.w, b.h, [snow]));
    meta[id] = { w: b.w, h: b.h, anchor: b.anchor };
    const pad = (a) => ({ defs: a.defs, body: `<svg width="200" height="210" viewBox="0 0 200 210"><g transform="translate(${(200 - b.w) / 2} ${210 - b.h})">${a.body}</g></svg>` });
    frames.push(pad(art));
    snowFrames.push(pad({ defs: [...art.defs, ...snow.defs], body: art.body + snow.body }));
  }
  fs.writeFileSync(`${out}/buildings.json`, JSON.stringify(meta, null, 1) + '\n');
  sheet(`out/buildings_preview.png`, 200, 210, frames.slice(0, 4), { scale: 2, bg: '#6aa84f' });
  sheet(`out/buildings_preview2.png`, 200, 210, frames.slice(4), { scale: 2, bg: '#6aa84f' });
  sheet(`out/buildings_snow.png`, 200, 210, snowFrames.slice(0, 4), { scale: 1.4, bg: '#dfe9f2' });
}
