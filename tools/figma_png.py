"""Экспорт PNG всех экранов (402x874) из дампа Figma в .design/png/."""
import os, sys, json, re, urllib.request, gzip, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

OUT = os.path.join(fig.ROOT, '.design', 'png')

def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')

def screens():
    """[(key, id, section, name)] — все кадры-экраны на странице design."""
    design = next(p for p in fig.doc()['children'] if p['id'] == '0:1')
    found, counts = [], {}
    for sec in design['children']:
        sname = slug(sec['name'])
        for f in sec.get('children') or []:
            if f['type'] != 'FRAME':
                continue
            bb = f.get('absoluteBoundingBox') or {}
            if round(bb.get('width', 0)) != 402:
                continue
            base = f"{sname}--{slug(f['name'])}"
            counts[base] = counts.get(base, 0) + 1
            key = base if counts[base] == 1 else f"{base}-{counts[base]}"
            found.append((key, f['id'], sec['name'], f['name']))
    return found

def main():
    os.makedirs(OUT, exist_ok=True)
    file_key = fig.key()
    items = screens()
    print(f'экранов: {len(items)}')
    for i in range(0, len(items), 20):
        chunk = items[i:i + 20]
        res = fig.api(f'/v1/images/{file_key}', {'ids': ','.join(c[1] for c in chunk), 'format': 'png', 'scale': '2'})
        for key, nid, _, _ in chunk:
            url = (res.get('images') or {}).get(nid)
            if not url:
                print('нет рендера:', key, nid)
                continue
            dst = os.path.join(OUT, key + '.png')
            with urllib.request.urlopen(url, timeout=900) as r, open(dst, 'wb') as f:
                f.write(r.read())
        print(f'  {min(i+20, len(items))}/{len(items)}')
    with open(os.path.join(fig.ROOT, '.design', 'screens.json'), 'w') as f:
        json.dump([{'key': k, 'id': n, 'section': s, 'name': nm} for k, n, s, nm in items], f,
                  ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()
