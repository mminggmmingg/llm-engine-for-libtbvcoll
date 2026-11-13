# Which KV a flash-attention kernel must touch under a QSA mask, for several tile shapes (offline, from GGML_CUDA_FA_MASK_DUMP files).
#   masksim.py <mask-...-kv<N>-q<M>-<name>.f16> [...]  [--q 1,4,8,16] [--kv 16,32,64] [--rows <real query rows>]
# A tile of q queries x kv cells is computed when any of its q queries sees any of its kv cells (the masked-chunk skip of 11-12/13).
# Prints, per (q, kv): computed chunk share of all chunks, and the cells read relative to an exact gather (each query reads only
# the cells it sees; the sparse-gather limit). Also the overlap between queries: mean selected cells per query vs. their union per tile.
import sys, numpy as np
args = [a for a in sys.argv[1:] if not a.startswith('--')]
opt = {sys.argv[i][2:]: sys.argv[i + 1] for i in range(1, len(sys.argv) - 1) if sys.argv[i].startswith('--')}
args = [a for a in args if a not in opt.values()]
QS = [int(x) for x in opt.get('q', '1,4,8,16').split(',')]
KS = [int(x) for x in opt.get('kv', '16,32,64').split(',')]
for fn in args:
    import re
    m = re.search(r'kv(\d+)-q(\d+)', fn)
    n_kv, n_q = int(m.group(1)), int(m.group(2))
    a = np.fromfile(fn, dtype=np.float16)
    a = a[: n_kv * n_q].reshape(n_q, n_kv)
    vis = np.isfinite(a)
    rows = int(opt.get('rows', 0)) or int(np.max(np.nonzero(vis.any(axis=1))[0]) + 1)
    vis = vis[:rows]
    sel = vis.sum(axis=1)
    print(f'{fn.split("/")[-1]}: kv {n_kv}, query rows {rows} (of {n_q}), visible cells per query mean {sel.mean():.0f} ({sel.mean() / n_kv:.2%})')
    print('  q  kv | computed chunks | cells read / exact gather | union cells per tile / mean per query')
    for q in QS:
        nt = (rows + q - 1) // q
        pad = np.zeros((nt * q - rows, n_kv), bool)
        v = np.concatenate([vis, pad]).reshape(nt, q, n_kv)
        tile_any = v.any(axis=1)                       # [nt, n_kv]: union of the tile's queries
        uni = tile_any.sum(axis=1).mean()
        for k in KS:
            nk = (n_kv + k - 1) // k
            t = np.concatenate([tile_any, np.zeros((nt, nk * k - n_kv), bool)], axis=1).reshape(nt, nk, k).any(axis=2)
            frac = t.mean()
            cells = t.sum() * k * q                      # every query of a computed tile multiplies every cell of the chunk
            print(f'{q:3d} {k:3d} | {frac:14.1%} | {cells / max(1, sel.sum()):10.1f}x | {uni:8.0f} / {sel.mean():.0f}')
