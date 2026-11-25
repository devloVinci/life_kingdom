// Life Kingdom skeletal hero runtime (web preview). Same math as the Flutter
// runtime: bones (x, y, rot clockwise in degrees, sx, sy, y down), eased
// keyframes, two-segment legs that keep feet planted (rotate + squash toward
// the foot target, so knees read as bending toward the camera in 3/4 view).
const LKRig = (() => {
  const EASE = {
    linear: u => u,
    smooth: u => u * u * (3 - 2 * u),
    in: u => u * u * u,
    out: u => 1 - (1 - u) ** 3,
    back: u => { const c = 1.9; return 1 + (c + 1) * (u - 1) ** 3 + c * (u - 1) ** 2; },
  };
  function sample(tr, t, def) {
    if (!tr || !tr.length) return def;
    if (t <= tr[0][0]) return tr[0][1];
    for (let i = 0; i < tr.length - 1; i++) {
      const a = tr[i], b = tr[i + 1];
      if (t <= b[0]) {
        const u = b[0] === a[0] ? 1 : (t - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * (EASE[b[2] || 'smooth'] || EASE.smooth)(u);
      }
    }
    return tr[tr.length - 1][1];
  }
  // canvas-style affine [a,b,c,d,e,f]: x' = a x + c y + e ; y' = b x + d y + f
  const mul = (m, n) => [
    m[0] * n[0] + m[2] * n[1], m[1] * n[0] + m[3] * n[1],
    m[0] * n[2] + m[2] * n[3], m[1] * n[2] + m[3] * n[3],
    m[0] * n[4] + m[2] * n[5] + m[4], m[1] * n[4] + m[3] * n[5] + m[5]];
  const inv = m => {
    const det = m[0] * m[3] - m[1] * m[2];
    return [m[3] / det, -m[1] / det, -m[2] / det, m[0] / det,
      (m[2] * m[5] - m[3] * m[4]) / det, (m[1] * m[4] - m[0] * m[5]) / det];
  };
  const apply = (m, x, y) => [m[0] * x + m[2] * y + m[4], m[1] * x + m[3] * y + m[5]];
  const local = (x, y, rot, sx, sy) => {
    const r = rot * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
    return [c * sx, s * sx, -s * sy, c * sy, x, y];
  };

  class Rig {
    constructor(data, images) {
      this.d = data; this.img = images;
      this.idx = {}; data.bones.forEach((b, i) => { this.idx[b.name] = i; });
      this.par = data.bones.map(b => (b.parent ? this.idx[b.parent] : -1));
      this.bind = this.world(null, 0, 1).map(m => [m[4], m[5]]);
      this.legs = (data.legs || []).map(L => {
        const th = this.idx[L.thigh], ft = this.idx[L.foot];
        return { th, ft, v0: [this.bind[ft][0] - this.bind[th][0], this.bind[ft][1] - this.bind[th][1]] };
      });
    }
    world(clip, t, facing) {
      const tr = clip ? clip.tracks : {};
      const W = [];
      this.d.bones.forEach((b, i) => {
        const k = tr[b.name] || {};
        let sx = sample(k.sx, t, 1); if (i === 0) { sx *= facing; if (Math.abs(sx) < 0.06) sx = sx < 0 ? -0.06 : 0.06; }
        const L = local(b.x + sample(k.x, t, 0), b.y + sample(k.y, t, 0), sample(k.rot, t, 0), sx, sample(k.sy, t, 1));
        W[i] = this.par[i] < 0 ? L : mul(W[this.par[i]], L);
      });
      if (!clip || !this.legs) return W;
      const R = W[0], Ri = inv(R);
      for (const g of this.legs) {
        const H = apply(Ri, W[g.th][4], W[g.th][5]);
        const T = apply(Ri, W[g.ft][4], W[g.ft][5]);
        const v = [T[0] - H[0], T[1] - H[1]];
        const n0 = Math.hypot(...g.v0), n = Math.hypot(...v);
        const da = Math.atan2(v[1], v[0]) - Math.atan2(g.v0[1], g.v0[0]);
        const s = n / n0;
        const c = Math.cos(da), si = Math.sin(da), vol = 1 + (1 - s) * 0.35;
        // squash/stretch along the rest leg direction, then rotate onto the target
        const ux = g.v0[0] / n0, uy = g.v0[1] / n0;
        const s00 = 1 + (s - 1) * ux * ux + (vol - 1) * uy * uy;
        const s11 = 1 + (s - 1) * uy * uy + (vol - 1) * ux * ux;
        const s01 = (s - 1) * ux * uy - (vol - 1) * ux * uy;
        const Lr = [c * s00 - si * s01, si * s00 + c * s01, c * s01 - si * s11, si * s01 + c * s11, H[0], H[1]];
        W[g.th] = mul(R, Lr);
        // children of the thigh (shin) follow
        this.d.bones.forEach((b, i) => {
          if (this.par[i] === g.th) {
            const k = tr[b.name] || {};
            W[i] = mul(W[g.th], local(b.x + sample(k.x, t, 0), b.y + sample(k.y, t, 0), sample(k.rot, t, 0), sample(k.sx, t, 1), sample(k.sy, t, 1)));
          }
        });
      }
      return W;
    }
    draw(ctx, W, view) {
      for (const s of this.d.slots) {
        const m = s.m, A = [m[0], m[3], m[1], m[4], m[2], m[5]];
        const M = mul(view, mul(W[this.idx[s.bone]], A));
        ctx.setTransform(M[0], M[1], M[2], M[3], M[4], M[5]);
        ctx.drawImage(this.img[s.name], 0, 0);
      }
      ctx.setTransform(1, 0, 0, 1, 0, 0);
    }
    point(W, view, bone, at) {
      const i = this.idx[bone], b = this.bind[i];
      const p = apply(W[i], at[0] - b[0], at[1] - b[1]);
      return apply(view, p[0], p[1]);
    }
  }
  return { Rig, sample, mul, apply };
})();
