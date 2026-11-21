# s4same.py IMG GUESTPATH NEWFILE - write NEWFILE over GUESTPATH in a 3B1
# disk image, in place: same size, same blocks, nothing else changes (not
# the inode, not the times). Only with the VM off.
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import s4img as s4

img, path, new = sys.argv[1:4]
data = open(new, 'rb').read()
vol = s4.Vol(img, write=True)
fs = s4.FS(vol)
ip = fs.lookup(path)
if ip['size'] != len(data):
    sys.exit('%s is %d bytes, %s is %d: not the same size' % (path, ip['size'], new, len(data)))
blocks = fs.blocks(ip)
if 0 in blocks:
    sys.exit('%s has a hole' % path)
changed = 0
for i, b in enumerate(blocks):
    chunk = data[i * 1024:(i + 1) * 1024]
    old = fs.block(b)
    chunk = chunk + old[len(chunk):]	# the last block: keep the bytes past the end
    if chunk != old:
        vol.write_sector(fs.part, b * 2, chunk[:512])
        vol.write_sector(fs.part, b * 2 + 1, chunk[512:])
        changed += 1
vol.f.close()
check = s4.FS(s4.Vol(img)).read(s4.FS(s4.Vol(img)).lookup(path))
print('%s: %d of %d blocks written, %s' % (path, changed, len(blocks), 'same as the file' if check == data else 'DIFFERENT'))
