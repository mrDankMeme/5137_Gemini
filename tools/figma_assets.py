"""Ассеты из Figma в Assets.xcassets.

Забираем **исходные** файлы изображений (`/v1/files/{key}/images`), а не рендеры:
они в полном разрешении, не расходуют лимит рендера и не требуют трёх плотностей.
Композиции, которые исходником не являются (арты онбординга), рендерим отдельно.
"""
import os, sys, json, time, gzip, urllib.request, urllib.parse
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

XCASSETS = os.path.join(fig.ROOT, 'Gemini', 'Resources', 'Assets.xcassets')

# имя ассета -> префикс imageRef из дампа
SOURCE_IMAGES = {
    'PaywallCrown':    '7c146f59',  # пластиковая корона на пейволе Go Pro
    'TokenCoins':      '5d6b2b7d',  # монеты на пейволе токенов
    'SpecialOfferArt': '06784197',  # фон спецпредложения
    'RateStar':        '8c17662c',  # пластиковая звезда на экране оценки
}

# имя ассета -> id узла: композиции, которые надо рендерить
RENDERED = {
    'OnboardingArt1': '33115:14925',
    'OnboardingArt2': '33115:14970',
    'OnboardingArt3': '35083:17192',
}

def save(name, url, suffix=''):
    folder = os.path.join(XCASSETS, name + '.imageset')
    os.makedirs(folder, exist_ok=True)
    dst = os.path.join(folder, f'{name}{suffix}.png')
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return
    with urllib.request.urlopen(url, timeout=900) as r:
        open(dst, 'wb').write(r.read())

def write_contents(name, scales):
    folder = os.path.join(XCASSETS, name + '.imageset')
    if scales:
        images = [
            {'idiom': 'universal', 'filename': f'{name}{"" if s == 1 else f"@{s}x"}.png', 'scale': f'{s}x'}
            for s in scales
        ]
    else:
        images = [{'idiom': 'universal', 'filename': f'{name}.png'}]
    json.dump({'images': images, 'info': {'author': 'xcode', 'version': 1}},
              open(os.path.join(folder, 'Contents.json'), 'w'), indent=2)

def main():
    FILE_KEY = fig.key()
    refs = fig.api(f'/v1/files/{FILE_KEY}/images')['meta']['images']
    for name, prefix in SOURCE_IMAGES.items():
        match = next((k for k in refs if k.startswith(prefix)), None)
        if not match:
            print('исходник не найден:', name)
            continue
        save(name, refs[match])
        write_contents(name, scales=None)  # оригинал — одна плотность
        print('исходник:', name, flush=True)

    res = fig.api(f'/v1/images/{FILE_KEY}', {'ids': ','.join(RENDERED.values()), 'format': 'png', 'scale': '3'})
    by_id = {v: k for k, v in RENDERED.items()}
    for nid, url in (res.get('images') or {}).items():
        name = by_id[nid]
        save(name, url, '@3x')
        write_contents(name, scales=[3])
        print('рендер:', name, flush=True)

if __name__ == '__main__':
    main()
