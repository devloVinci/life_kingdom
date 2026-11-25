#!/usr/bin/env python3
"""Self-contained HTML preview of a built hero rig (runs at display frame rate).

  python make_preview.py RIG_DIR OUT.html
"""
import base64, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

PAGE = r"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>__NAME__ preview</title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Lilita+One&family=Nunito:wght@600;800&display=swap" rel="stylesheet">
<style>
/* VOICE: a game's hero-select screen, warm and punchy
   IDEA: the troop preview stage of a kingdom strategy game
   PICTURE: the hero on a sunlit 3/4 grass field, large, alive
   COLOUR and TYPE: meadow green field, wood-brown controls, gold accent; Lilita One + Nunito
   LAYOUT: stage first and wide, controls in one wooden bar under it */
:root{color-scheme:light dark;--bg:light-dark(#2f5d1e,#14240d);--ink:#fff8e6;--wood:#6b4423;--wood2:#8a5a2e;--gold:#ffc83d}
*{box-sizing:border-box;min-width:0}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.5 Nunito,system-ui,sans-serif;overflow-x:clip}
header{padding:14px max(4vw,14px) 6px;display:flex;align-items:baseline;gap:12px;flex-wrap:wrap}
h1{font:400 clamp(26px,4vw,40px)/1.05 'Lilita One',system-ui;margin:0;letter-spacing:.5px;text-shadow:0 3px 0 #0006}
header p{margin:0;opacity:.85;font-size:14px}
.stage{position:relative;margin:6px max(4vw,14px) 0;border-radius:18px;overflow:hidden;border:4px solid #2a1a0c;box-shadow:0 8px 0 #0005;height:min(64vh,560px);min-height:340px}
.stage canvas{position:absolute;inset:0;width:100%;height:100%;display:block;cursor:pointer}
.bar{margin:14px max(4vw,14px) 24px;background:linear-gradient(var(--wood2),var(--wood));border:3px solid #2a1a0c;border-radius:16px;padding:10px;display:flex;flex-wrap:wrap;gap:8px;align-items:center}
button{font:800 15px Nunito,system-ui;color:#2a1a0c;background:linear-gradient(#ffe08a,var(--gold));border:3px solid #2a1a0c;border-radius:12px;min-height:44px;padding:0 16px;box-shadow:0 4px 0 #2a1a0c;cursor:pointer}
button:active{transform:translateY(3px);box-shadow:0 1px 0 #2a1a0c}
button[aria-pressed=true]{background:linear-gradient(#a8f07a,#5fc53b)}
button:focus-visible,input:focus-visible{outline:3px solid #fff;outline-offset:2px}
.sep{flex:1 1 12px}
label{display:flex;align-items:center;gap:8px;font-weight:800;font-size:14px}
input[type=range]{width:120px;accent-color:var(--gold)}
input[type=checkbox]{width:22px;height:22px;accent-color:var(--gold)}
.note{margin:-12px max(4vw,14px) 22px;font-size:13px;opacity:.75}
@media(max-width:600px){.stage{height:58vh}button{padding:0 12px}}
</style></head><body>
<header><h1>__NAME__</h1><p>Tap the hero to attack. Roam lets him wander the field.</p></header>
<div class="stage"><canvas id="cv"></canvas></div>
<div class="bar" id="bar">
 <button data-a="idle">Idle</button><button data-a="walk">Walk</button><button data-a="attack">Attack</button>
 <button data-a="victory">Victory</button><button data-a="hit">Hit</button>
 <button id="roam" aria-pressed="true">Roam</button><span class="sep"></span>
 <label>Speed <input id="spd" type="range" min="0.2" max="1.5" step="0.05" value="1"></label>
 <label><input id="bones" type="checkbox"> Bones</label>
</div>
<p class="note">Live skeletal animation rendered in the browser from 14 painted parts.</p>
<script>__RUNTIME__</script>
<script>
{
const RIG = __RIG__;
const IMGS = __IMGS__;
const cv = document.getElementById('cv'), ctx = cv.getContext('2d');
const off = document.createElement('canvas'), octx = off.getContext('2d');
const bgc = document.createElement('canvas'), bctx = bgc.getContext('2d');
let rig = null, W = 0, H = 0, dpr = 1;
const images = {}; let left = Object.keys(IMGS).length;
for (const [k, src] of Object.entries(IMGS)) { const im = new Image(); im.onload = () => { if (--left === 0) start(); }; im.src = src; images[k] = im; }

const st = { clip: 'idle', t: 0, face: 1, x: 0.45, y: 0.62, roam: true, target: null, wait: 1.2, speed: 1, after: null };
const fx = { dust: [], rings: [] };

function size() {
  dpr = Math.min(2, window.devicePixelRatio || 1);
  const r = cv.getBoundingClientRect(); W = r.width; H = r.height;
  for (const c of [cv, off, bgc]) { c.width = Math.round(W * dpr); c.height = Math.round(H * dpr); }
  paintField();
}
function rnd(s) { return () => (s = (s * 16807) % 2147483647) / 2147483647; }
function paintField() {
  const c = bctx; c.setTransform(dpr, 0, 0, dpr, 0, 0);
  const g = c.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#6fae3c'); g.addColorStop(1, '#4f8f2a');
  c.fillStyle = g; c.fillRect(0, 0, W, H);
  const r = rnd(7);
  for (let i = 0; i < 26; i++) { c.fillStyle = 'rgba(255,255,200,.07)'; c.beginPath(); c.ellipse(r() * W, r() * H, 60 + r() * 90, 18 + r() * 26, 0, 0, 7); c.fill(); }
  // dirt path running down-right (3/4 view)
  c.strokeStyle = '#3c2914'; c.lineWidth = H * 0.2; c.lineCap = 'round';
  c.beginPath(); c.moveTo(-40, H * 0.35); c.bezierCurveTo(W * 0.3, H * 0.45, W * 0.55, H * 0.75, W + 40, H * 0.95); c.stroke();
  c.strokeStyle = '#c99b5c'; c.lineWidth = H * 0.18; c.stroke();
  c.strokeStyle = 'rgba(255,240,200,.25)'; c.lineWidth = H * 0.05; c.stroke();
  for (let i = 0; i < 90; i++) { const x = r() * W, y = r() * H; c.strokeStyle = r() < .5 ? '#3f7a22' : '#7cc24a'; c.lineWidth = 2;
    c.beginPath(); c.moveTo(x, y); c.lineTo(x - 4, y - 9); c.moveTo(x, y); c.lineTo(x + 1, y - 11); c.moveTo(x, y); c.lineTo(x + 5, y - 8); c.stroke(); }
  for (let i = 0; i < 14; i++) { const x = r() * W, y = r() * H; c.fillStyle = ['#fff3a8', '#ffb3c8', '#ffffff'][i % 3]; c.beginPath(); c.arc(x, y, 3, 0, 7); c.fill(); }
  const v = c.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H); v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(0,0,0,.35)');
  c.fillStyle = v; c.fillRect(0, 0, W, H);
}

function play(name, then) {
  if (!RIG.clips[name]) return;
  st.clip = name; st.t = 0; st.after = then || null;
}
function scaleAt(y) { return (H * 0.5 / 830) * (0.82 + 0.36 * y); }

function start() {
  rig = new LKRig.Rig(RIG, images);
  size(); addEventListener('resize', size);
  let last = performance.now();
  requestAnimationFrame(function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000) * st.speed; last = now;
    step(dt); render(); requestAnimationFrame(loop);
  });
}

function step(dt) {
  const clip = RIG.clips[st.clip];
  st.t += dt;
  // fire events
  for (const [et, name] of clip.events || []) if (st.t - dt < et && st.t >= et) spawn(name);
  if (!clip.loop && st.t >= clip.dur) { const nx = st.after || (st.roam ? 'idle' : 'idle'); st.after = null; play(nx); }
  if (st.roam) roam(dt);
  for (const d of fx.dust) d.t += dt; fx.dust = fx.dust.filter(d => d.t < d.life);
  for (const r of fx.rings) r.t += dt; fx.rings = fx.rings.filter(r => r.t < 0.6);
}
function roam(dt) {
  if (st.clip === 'walk' && st.target) {
    const k = scaleAt(st.y), sp = RIG.clips.walk.speed, v = Math.hypot(sp[0], sp[1]) * k;
    const tx = st.target[0] * W, ty = st.target[1] * H, x = st.x * W, y = st.y * H;
    const dx = tx - x, dy = ty - y, d = Math.hypot(dx, dy);
    if (d < 4) { st.target = null; play('idle'); st.wait = 1 + Math.random() * 1.8; return; }
    const m = Math.min(d, v * dt * 1.0);
    st.x = (x + dx / d * m) / W; st.y = (y + dy / d * m) / H;
    if (Math.abs(dx) > 2) st.face = dx < 0 ? -1 : 1;
  } else if (st.clip === 'idle') {
    st.wait -= dt;
    if (st.wait <= 0) {
      const r = Math.random();
      if (r < 0.22) { play('attack'); st.wait = 0.8; }
      else if (r < 0.32) { play('victory'); st.wait = 0.8; }
      else { st.target = [0.14 + Math.random() * 0.72, 0.42 + Math.random() * 0.48]; play('walk'); }
    }
  }
}
function spawn(name) {
  const k = scaleAt(st.y), gx = st.x * W, gy = st.y * H;
  if (name === 'dust') for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2 + Math.random() * .3;
    fx.dust.push({ x: gx, y: gy, vx: Math.cos(a) * (120 + Math.random() * 90) * k * 2.2, vy: Math.sin(a) * (40 + Math.random() * 30) * k * 2.2, r: (18 + Math.random() * 14) * k * 2.2, t: 0, life: .6 + Math.random() * .3 }); }
  if (name === 'ring') fx.rings.push({ x: gx, y: gy, k, t: 0 });
}

function render() {
  if (!rig) return;
  const clip = RIG.clips[st.clip];
  const t = clip.loop ? st.t % clip.dur : Math.min(st.t, clip.dur);
  const k = scaleAt(st.y), gx = st.x * W, gy = st.y * H;
  const shake = LKRig.sample(clip.tracks.fx && clip.tracks.fx.shake, t, 0);
  const sx = (Math.random() - .5) * 10 * shake, sy = (Math.random() - .5) * 6 * shake;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.drawImage(bgc, sx * dpr, sy * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, sx * dpr, sy * dpr);
  // ground shadow + rings + dust
  ctx.fillStyle = 'rgba(20,30,10,.38)'; ctx.beginPath(); ctx.ellipse(gx, gy - 4 * k, 190 * k, 50 * k, 0, 0, 7); ctx.fill();
  for (const r of fx.rings) { const u = r.t / 0.6; ctx.strokeStyle = `rgba(200,150,255,${(1 - u) * .8})`; ctx.lineWidth = 10 * (1 - u) + 2;
    ctx.beginPath(); ctx.ellipse(r.x, r.y, (120 + 420 * u) * r.k, (34 + 120 * u) * r.k, 0, 0, 7); ctx.stroke(); }
  const W2 = rig.world(clip, t, st.face);
  const view = [k, 0, 0, k, gx - RIG.ground[0] * k, gy - RIG.ground[1] * k];
  const spin = LKRig.sample(clip.tracks.fx && clip.tracks.fx.spin, t, 0);
  if (spin > 0 && spin < 1) smear(gx, gy, k, spin, true);
  octx.setTransform(1, 0, 0, 1, 0, 0); octx.clearRect(0, 0, off.width, off.height);
  const v2 = LKRig.mul([dpr, 0, 0, dpr, 0, 0], view);
  rig.draw(octx, W2, v2);
  const flash = LKRig.sample(clip.tracks.fx && clip.tracks.fx.flash, t, 0);
  if (flash > 0.01) { octx.globalCompositeOperation = 'source-atop'; octx.fillStyle = `rgba(255,255,255,${flash})`; octx.fillRect(0, 0, off.width, off.height); octx.globalCompositeOperation = 'source-over'; }
  ctx.setTransform(1, 0, 0, 1, sx * dpr, sy * dpr); ctx.drawImage(off, 0, 0);
  ctx.setTransform(dpr, 0, 0, dpr, sx * dpr, sy * dpr);
  // visor glow
  const glow = LKRig.sample(clip.tracks.fx && clip.tracks.fx.glow, t, 0.5);
  if (RIG.fx.visor) { const p = rig.point(W2, view, RIG.fx.visor.bone, RIG.fx.visor.at); const R = 70 * k * (0.6 + glow * 0.5);
    const g = ctx.createRadialGradient(p[0], p[1], 0, p[0], p[1], R); g.addColorStop(0, `rgba(220,160,255,${Math.min(.9, .35 * glow)})`); g.addColorStop(1, 'rgba(150,60,255,0)');
    ctx.globalCompositeOperation = 'lighter'; ctx.fillStyle = g; ctx.beginPath(); ctx.arc(p[0], p[1], R, 0, 7); ctx.fill(); ctx.globalCompositeOperation = 'source-over'; }
  if (spin > 0 && spin < 1) smear(gx, gy, k, spin, false);
  for (const d of fx.dust) { const u = d.t / d.life; ctx.fillStyle = `rgba(222,200,160,${(1 - u) * .75})`;
    ctx.beginPath(); ctx.ellipse(d.x + d.vx * d.t, d.y + d.vy * d.t - 30 * u * k * 2.2, d.r * (1 + u), d.r * .7 * (1 + u), 0, 0, 7); ctx.fill(); }
  if (document.getElementById('bones').checked) bonesOverlay(W2, view);
}
function smear(gx, gy, k, p, back) {
  const cy = gy - 300 * k, rx = 380 * k, ry = 120 * k, head = p * Math.PI * 2.3 - Math.PI * 0.5, tail = head - Math.PI * 1.25;
  const fade = Math.min(1, (1 - p) * 3);
  for (const [w, col] of [[34, '150,70,255'], [18, '205,160,255'], [6, '255,255,255']]) {
    const N = 40;
    for (let i = 0; i < N; i++) {
      const a0 = tail + (head - tail) * i / N, a1 = tail + (head - tail) * (i + 1) / N;
      const isBack = Math.sin((a0 + a1) / 2) < 0; if (isBack !== back) continue;
      ctx.strokeStyle = `rgba(${col},${(i / N) ** 1.4 * fade * (back ? .55 : .9)})`; ctx.lineWidth = w * k * 2.2 * (0.4 + 0.6 * i / N); ctx.lineCap = 'round';
      ctx.beginPath(); ctx.ellipse(gx, cy, rx, ry, 0, a0, a1); ctx.stroke();
    }
  }
}
function bonesOverlay(W2, view) {
  ctx.lineWidth = 2; ctx.strokeStyle = '#fff'; ctx.fillStyle = '#ff4fd8';
  RIG.bones.forEach((b, i) => { const p = LKRig.apply(view, W2[i][4], W2[i][5]);
    if (b.parent) { const j = rig.idx[b.parent], q = LKRig.apply(view, W2[j][4], W2[j][5]); ctx.beginPath(); ctx.moveTo(q[0], q[1]); ctx.lineTo(p[0], p[1]); ctx.stroke(); }
    ctx.beginPath(); ctx.arc(p[0], p[1], 4, 0, 7); ctx.fill(); });
}
document.getElementById('bar').addEventListener('click', e => {
  const b = e.target.closest('button'); if (!b) return;
  if (b.id === 'roam') { st.roam = !st.roam; b.setAttribute('aria-pressed', st.roam); if (!st.roam) { st.target = null; play('idle'); } return; }
  const a = b.dataset.a; if (!a) return;
  st.target = null; if (a === 'walk') { st.roam = false; document.getElementById('roam').setAttribute('aria-pressed', 'false'); }
  play(a);
});
cv.addEventListener('click', () => { if (st.clip !== 'attack') { st.target = null; play('attack'); } });
document.getElementById('spd').addEventListener('input', e => { st.speed = +e.target.value; });
}
</script></body></html>
"""


def main(rig_dir, out):
    rig = json.load(open(os.path.join(rig_dir, "rig.json")))
    imgs = {}
    for s in rig["slots"]:
        with open(os.path.join(rig_dir, s["image"]), "rb") as f:
            imgs[s["name"]] = "data:image/png;base64," + base64.b64encode(f.read()).decode()
    runtime = open(os.path.join(HERE, "lk_rig.js")).read()
    html = (PAGE.replace("__RUNTIME__", runtime).replace("__RIG__", json.dumps(rig))
            .replace("__IMGS__", json.dumps(imgs)).replace("__NAME__", rig["name"]))
    open(out, "w").write(html)
    print(out, round(len(html) / 1024), "KB")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
