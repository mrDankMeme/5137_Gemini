"""Рендер трёх артов онбординга. Отдельно, потому что Figma жёстко лимитирует /v1/images."""
import os, sys, json, time, gzip, urllib.request, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

XCASSETS = os.path.join(fig.ROOT, 'Gemini', 'Resources', 'Assets.xcassets')
NODES = {'OnboardingArt1': '33115:14925', 'OnboardingArt2': '33115:14970', 'OnboardingArt3': '35083:17192'}

def render(nid):
    url = (f'https://api.figma.com/v1/images/{FILE_KEY}?'
           + urllib.parse.urlencode({'ids': nid, 'format': 'png', 'scale': '3'}))
    req = urllib.request.Request(url, headers={'X-Figma-Token': TOKEN, 'Accept-Encoding': 'gzip'})
    for attempt in range(20):
        try:
            with urllib.request.urlopen(req, timeout=900) as r:
                raw = r.read()
                if r.headers.get('Content-Encoding') == 'gzip':
                    raw = gzip.decompress(raw)
            return json.loads(raw)['images'][nid]
        except urllib.error.HTTPError as error:
            if error.code != 429:
                raise
            wait = int(error.headers.get('Retry-After') or 60)
            print(f'  429 — пауза {wait} с (попытка {attempt + 1})', flush=True)
            time.sleep(wait)
    raise RuntimeError('лимит не отпустил за 20 попыток')

for name, nid in NODES.items():
    folder = os.path.join(XCASSETS, name + '.imageset')
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, f'{name}@3x.png')
    if not (os.path.exists(dst) and os.path.getsize(dst) > 0):
        url = render(nid)
        with urllib.request.urlopen(url, timeout=900) as r:
            open(dst, 'wb').write(r.read())
    json.dump(
        {'images': [{'idiom': 'universal', 'filename': f'{name}@3x.png', 'scale': '3x'}],
         'info': {'author': 'xcode', 'version': 1}},
        open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)
    print('готов:', name, flush=True)
print('все арты онбординга на месте')
