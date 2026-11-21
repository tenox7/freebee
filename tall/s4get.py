# s4get.py IMG OUTDIR GUESTPATH... - copy files out of a 3B1 disk image
# (read only). Each file goes to OUTDIR/<basename>.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import s4img as s4

img, out = sys.argv[1:3]
fs = s4.FS(s4.Vol(img))
for path in sys.argv[3:]:
    try:
        ip = fs.lookup(path)
    except Exception as e:
        print('%s: %s' % (path, e))
        continue
    if ip is None:
        print('%s: not found' % path)
        continue
    data = fs.read(ip)
    dst = os.path.join(out, os.path.basename(path))
    open(dst, 'wb').write(data)
    print('%s: %d bytes -> %s' % (path, len(data), dst))
