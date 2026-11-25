// Tiny helpers to write layered SVG character parts and render previews.
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const INK = '#1a1622';

let gid = 0;
let pending = [];
function uid(p) { return `${p}${++gid}`; }

/** Linear gradient def. stops: [[offset, color], ...]; angle in degrees (0 = left->right, 90 = top->bottom). */
function lin(stops, angle = 90) {
  const id = uid('l');
  const a = (angle * Math.PI) / 180;
  const x1 = 0.5 - Math.cos(a) / 2, y1 = 0.5 - Math.sin(a) / 2;
  const x2 = 0.5 + Math.cos(a) / 2, y2 = 0.5 + Math.sin(a) / 2;
  const def = `<linearGradient id="${id}" x1="${x1.toFixed(3)}" y1="${y1.toFixed(3)}" x2="${x2.toFixed(3)}" y2="${y2.toFixed(3)}">${stops
    .map(([o, c, op]) => `<stop offset="${o}" stop-color="${c}"${op != null ? ` stop-opacity="${op}"` : ''}/>`)
    .join('')}</linearGradient>`;
  pending.push(def);
  return { id, def, url: `url(#${id})` };
}

function rad(stops, cx = 0.4, cy = 0.35, r = 0.75) {
  const id = uid('r');
  const def = `<radialGradient id="${id}" cx="${cx}" cy="${cy}" r="${r}">${stops
    .map(([o, c, op]) => `<stop offset="${o}" stop-color="${c}"${op != null ? ` stop-opacity="${op}"` : ''}/>`)
    .join('')}</radialGradient>`;
  pending.push(def);
  return { id, def, url: `url(#${id})` };
}

/** A part = { defs: [], body: '' }. Shapes are strings. */
function part(...items) {
  const defs = pending;
  pending = [];
  const body = [];
  for (const it of items.flat(Infinity)) {
    if (!it) continue;
    if (typeof it === 'string') body.push(it);
  }
  return { defs, body: body.join('\n') };
}

function p(d, fill, o = {}) {
  const f = typeof fill === 'object' ? fill.url : fill;
  const sw = o.sw ?? 0;
  const stroke = sw ? ` stroke="${o.stroke ?? INK}" stroke-width="${sw}" stroke-linejoin="round" stroke-linecap="round"` : '';
  const op = o.op != null ? ` opacity="${o.op}"` : '';
  return `<path d="${d}" fill="${f ?? 'none'}"${stroke}${op}/>`;
}
function stroke(d, color, w, o = {}) {
  const op = o.op != null ? ` opacity="${o.op}"` : '';
  return `<path d="${d}" fill="none" stroke="${color}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"${op}/>`;
}
function ell(cx, cy, rx, ry, fill, o = {}) {
  const f = typeof fill === 'object' ? fill.url : fill;
  const sw = o.sw ?? 0;
  const s = sw ? ` stroke="${o.stroke ?? INK}" stroke-width="${sw}"` : '';
  const op = o.op != null ? ` opacity="${o.op}"` : '';
  return `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${f}"${s}${op}/>`;
}

/** Shape outlined: draws the ink stroke first (behind), then the fill. */
function inked(d, fill, w = 1.7) {
  return [p(d, 'none', { sw: w * 2, stroke: INK }), p(d, fill)];
}

function svgDoc(w, h, parts) {
  const defs = parts.flatMap((x) => x.defs);
  const body = parts.map((x) => x.body).join('\n');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" fill="none">\n<defs>${defs.join('')}</defs>\n${body}\n</svg>\n`;
}

/** Writes one SVG per part into dir and a rig.json. */
function writeRig(dir, { name, slug, w, h, parts, pivots }) {
  fs.mkdirSync(dir, { recursive: true });
  for (const f of fs.readdirSync(dir)) if (f.endsWith('.svg')) fs.unlinkSync(path.join(dir, f));
  const meta = [];
  for (const pt of parts) {
    fs.writeFileSync(path.join(dir, pt.file), svgDoc(w, h, [pt.art]));
    meta.push({ name: pt.name, file: pt.file, role: pt.role });
  }
  fs.writeFileSync(
    path.join(dir, 'rig.json'),
    JSON.stringify({ name, slug, width: w, height: h, parts: meta, pivots }, null, 1) + '\n',
  );
}

/** Composite with per-role transforms {role: {dx, dy, rot(rad), sx, sy}} for previews. */
function composite(rig, pose = {}) {
  const { w, h, parts, pivots } = rig;
  const groups = parts.map((pt) => {
    const t = { dx: 0, dy: 0, rot: 0, sx: 1, sy: 1, ...(pose[pt.role] || {}) };
    const root = pt.role === 'shadow' ? {} : pose.root || {};
    const dx = t.dx + (root.dx || 0), dy = t.dy + (root.dy || 0), rot = t.rot + (root.rot || 0);
    const [px, py] = pivots[pt.role] || [w / 2, h / 2];
    const tr = `translate(${dx} ${dy}) translate(${px} ${py}) rotate(${(rot * 180) / Math.PI}) scale(${t.sx} ${t.sy}) translate(${-px} ${-py})`;
    return { defs: pt.art.defs, body: `<g transform="${tr}">${pt.art.body}</g>` };
  });
  return { defs: groups.flatMap((g) => g.defs), body: groups.map((g) => g.body).join('\n') };
}

/** Renders a row of frames (each a part) to PNG, with a background color. */
function sheet(file, w, h, frames, { scale = 3, bg = '#3a4a3a', label } = {}) {
  const W = w * frames.length;
  const defs = [];
  const bodies = frames.map((f, i) => {
    defs.push(...f.defs);
    return `<g transform="translate(${i * w} 0)">${f.body}</g>`;
  });
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${h}" viewBox="0 0 ${W} ${h}"><defs>${defs.join('')}</defs><rect width="${W}" height="${h}" fill="${bg}"/>${bodies.join('')}</svg>`;
  const png = new Resvg(svg, { fitTo: { mode: 'zoom', value: scale } }).render().asPng();
  fs.writeFileSync(file, png);
}

module.exports = { INK, lin, rad, part, p, stroke, ell, inked, svgDoc, writeRig, composite, sheet };
