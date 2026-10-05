"""Merge and split overlay capture files (psxrecomp overlay capture v2). Hand-written, stdlib only.

  python captures.py merge --out all.json a.json b.json ...
      One capture per (load_addr, exact bytes). The same code captured twice (from the disc and from
      the phone, or two play sessions) is kept once, with the union of its PC lists (seeds, executed
      PCs, entry points), so every way of reaching that code is compiled. Missing inputs are skipped.
  python captures.py split --in all.json --groups 8 --outdir par
      Size-balanced groups par/g00.json, g01.json, ... (largest first onto the lightest group), one
      compile process per group. Old gNN.json files in --outdir are removed first.
  python captures.py digest all.json
      Prints a short fingerprint of the capture set: unchanged captures need no recompile.
"""
import argparse, base64, glob, hashlib, json, os, sys

LIST_KEYS = ("executed_pcs", "dispatch_entry_pcs", "function_entry_pcs", "seeds")


def load(path):
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return data if isinstance(data, list) else data.get("captures", [])


def key(c):
    raw = base64.b64decode(c.get("bytes_b64", ""))
    return (int(str(c.get("load_addr", "0")), 16), hashlib.sha256(raw).hexdigest())


def merge(args):
    out, order = {}, []
    for path in args.inputs:
        for c in load(path):
            k = key(c)
            if k not in out:
                out[k] = dict(c)
                order.append(k)
                continue
            have = out[k]
            for lk in LIST_KEYS:
                if lk in c or lk in have:
                    have[lk] = sorted(set(have.get(lk, [])) | set(c.get(lk, [])), key=lambda s: int(s, 16))
    merged = [out[k] for k in order]
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(merged, f)
    print(f"merged {len(merged)} capture(s) into {args.out}")


def split(args):
    caps = load(args.inp)
    os.makedirs(args.outdir, exist_ok=True)
    for old in glob.glob(os.path.join(args.outdir, "g[0-9][0-9].json")):
        os.remove(old)
    n = max(1, min(args.groups, len(caps)))
    groups = [[] for _ in range(n)]
    sizes = [0] * n
    for c in sorted(caps, key=lambda c: int(c.get("size", 0)), reverse=True):
        i = sizes.index(min(sizes))
        groups[i].append(c)
        sizes[i] += int(c.get("size", 0))
    for i, g in enumerate(groups):
        with open(os.path.join(args.outdir, f"g{i:02d}.json"), "w", encoding="utf-8") as f:
            json.dump(g, f)
    print(f"split {len(caps)} capture(s) into {n} group(s)")


def digest(args):
    h = hashlib.sha256()
    for c in sorted(load(args.inp), key=key):
        h.update(repr(key(c)).encode())
        for lk in LIST_KEYS:
            h.update(repr(sorted(c.get(lk, []))).encode())
    print(h.hexdigest()[:16])


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("merge"); m.add_argument("--out", required=True); m.add_argument("inputs", nargs="+")
    s = sub.add_parser("split"); s.add_argument("--in", dest="inp", required=True)
    s.add_argument("--groups", type=int, default=8); s.add_argument("--outdir", required=True)
    d = sub.add_parser("digest"); d.add_argument("inp")
    a = p.parse_args()
    {"merge": merge, "split": split, "digest": digest}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
