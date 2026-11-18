"""(v0.30) Pack the project into zips that each stay under a size limit (an upload to Claude takes up to 30 MB a file).

  python3 tools/pack_parts.py <project_dir> <out_dir> <name> [--limit-mb 24]

Every part is an ordinary zip with the same top folder <name>/, so extracting all of them "here" into one place gives the
whole project back (7-Zip / WinRAR: select all parts -> Extract Here). Part 1 holds the code, data and docs; the art and the
music follow, folder by folder. PARTS.txt (in part 1) lists every part and how many files it holds, so a missing part
shows at once.
"""
import os
import sys
import zipfile

SKIP_DIRS = {".godot", "build", "__pycache__", ".git"}
SKIP_EXT = {".so"}


def files_of(root):
    out = []
    for d, dirs, fs in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(fs):
            if os.path.splitext(f)[1] in SKIP_EXT:
                continue
            p = os.path.join(d, f)
            out.append((os.path.relpath(p, root), os.path.getsize(p)))
    return out


def main():
    root, out_dir, name = sys.argv[1], sys.argv[2], sys.argv[3]
    limit = int(float(sys.argv[sys.argv.index("--limit-mb") + 1]) * 1024 * 1024) if "--limit-mb" in sys.argv else 24 * 1024 * 1024
    allf = files_of(root)
    # (v0.32) three groups packed apart, so an update that touches only the code or only the art leaves the other
    # parts as they were: code (code, data, docs, tools, fonts, icons), art, audio
    group_of = lambda rel: "art" if rel.startswith("assets/art/") else ("audio" if rel.startswith("assets/audio/") else "code")
    parts, labels = [], []
    for g in ["code", "art", "audio"]:
        cur, size, n = [], 0, 0
        for f in [f for f in allf if group_of(f[0]) == g]:
            if cur and size + f[1] > limit:
                n += 1
                parts.append(cur)
                labels.append("%s%d" % (g, n))
                cur, size = [], 0
            cur.append(f)
            size += f[1]
        if cur:
            n += 1
            parts.append(cur)
            labels.append("%s%d" % (g, n))
    os.makedirs(out_dir, exist_ok=True)
    import hashlib
    top = sys.argv[sys.argv.index("--top") + 1] if "--top" in sys.argv else name
    n = len(parts)
    sums = []
    for p in parts:
        h = hashlib.md5()
        for rel, _ in p:
            h.update(rel.encode())
            h.update(open(os.path.join(root, rel), "rb").read())
        sums.append(h.hexdigest()[:12])
    listing = ["%s — %d parts. Extract every part into the same folder (Extract Here, replace all)." % (name, n)]
    for lab, p, sm in zip(labels, parts, sums):
        listing.append("%s: %d files, content %s" % (lab, len(p), sm))
    paths = []
    for i, (lab, p) in enumerate(zip(labels, parts), 1):
        zp = os.path.join(out_dir, "%s_%s.zip" % (name, lab))
        with zipfile.ZipFile(zp, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for rel, _ in p:
                z.write(os.path.join(root, rel), os.path.join(top, rel))
            if lab == "code1":
                z.writestr(os.path.join(top, "PARTS.txt"), "\n".join(listing) + "\n")
        paths.append(zp)
        print(zp, "%.1f MB" % (os.path.getsize(zp) / 1048576.0), len(p), "files")
    if any(os.path.getsize(z) > 29.5 * 1024 * 1024 for z in paths):
        raise SystemExit("a part is over 29.5 MB: lower --limit-mb")


if __name__ == "__main__":
    main()
