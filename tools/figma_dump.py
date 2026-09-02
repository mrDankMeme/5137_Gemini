"""Один запрос за весь файл Figma → .design/file.json.

Это единственный тяжёлый вызов во всей связке: дальше геометрия читается
офлайн через fig.py, без сети и без расхода квоты. Квота Figma на /v1/files
считается по файлу и выдаётся сутками — поэтому дамп делается один раз,
а не «по экрану, когда понадобится».

    python3 tools/figma_dump.py <ключ-файла | ссылка на макет>
    python3 tools/figma_dump.py                        # ключ из .design/key
    python3 tools/figma_dump.py --from-plugin <файл>   # выгрузка плагина
"""
import os, re, sys, json, unicodedata
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

DESIGN = os.path.join(fig.ROOT, '.design')


def parse_key(arg):
    """Принимает и голый ключ, и ссылку вида figma.com/design/<key>/<name>."""
    m = re.search(r'figma\.com/(?:file|design)/([A-Za-z0-9]+)', arg)
    return m.group(1) if m else arg.strip()


def adopt_plugin_dump(path):
    """Кладёт на место выгрузку плагина «Design Dump».

    Нужна, когда REST упёрся в лимит: плагин работает внутри Figma, квоту
    не тратит и отдаёт больше — привязки переменных, стили и свойства
    компонентов, которых в ответе REST нет.
    """
    os.makedirs(DESIGN, exist_ok=True)
    data = json.load(open(path))
    if 'pages' not in data:
        raise SystemExit(f'это не выгрузка плагина: {path}')
    dst = os.path.join(DESIGN, 'file.json')
    with open(dst, 'w') as f:
        json.dump(data, f, ensure_ascii=False)
    write_screen_index()
    size = os.path.getsize(dst) / 1024 / 1024
    print(f"«{data.get('name')}» · страниц {len(data['pages'])} · {size:.1f} МБ -> {dst}")
    for page in data['pages']:
        frames = sum(1 for c in (page.get('children') or []) if c.get('type') == 'FRAME')
        print(f"  {page['id']:10} {page['name']}  ({frames} кадров)")


def slug(text):
    """Имя экрана в ключ. Эмодзи из названий страниц выкидываем."""
    cleaned = ''.join(c for c in text if unicodedata.category(c)[0] != 'S')
    return re.sub(r'[^a-z0-9]+', '-', cleaned.lower()).strip('-')


def write_screen_index():
    """`.design/screens.json` — ключ экрана к его node-id.

    Строится из дампа, а не из рендера: `/v1/images` лимитирована, а индекс
    нужен всегда, даже когда картинок не забрать.
    """
    fig.doc.cache_clear()
    fig.raw.cache_clear()
    fig.index.cache_clear()

    found, counts = [], {}
    for page in fig.doc()['children']:
        page_key = slug(page['name'])
        for section in page.get('children') or []:
            section_key = slug(section.get('name', ''))
            for frame in section.get('children') or []:
                box = frame.get('absoluteBoundingBox') or {}
                if frame.get('type') != 'FRAME' or round(box.get('width', 0)) != 402:
                    continue
                base = f"{section_key}--{slug(frame['name'])}"
                counts[base] = counts.get(base, 0) + 1
                key = base if counts[base] == 1 else f'{base}-{counts[base]}'
                found.append({'key': key, 'id': frame['id'], 'page': page['name'],
                              'section': section.get('name', ''), 'name': frame['name']})

    with open(os.path.join(DESIGN, 'screens.json'), 'w') as f:
        json.dump(found, f, ensure_ascii=False, indent=1)
    print(f'экранов в индексе: {len(found)}')


def main():
    if len(sys.argv) > 1 and sys.argv[1] == '--from-plugin':
        if len(sys.argv) < 3:
            raise SystemExit('укажите путь: --from-plugin <файл>')
        adopt_plugin_dump(sys.argv[2])
        return

    os.makedirs(DESIGN, exist_ok=True)
    if len(sys.argv) > 1:
        key = parse_key(sys.argv[1])
        open(fig.KEYFILE, 'w').write(key + '\n')
    else:
        key = fig.key()

    print(f'файл: {key}')
    data = fig.api(f'/v1/files/{key}')

    dst = os.path.join(DESIGN, 'file.json')
    with open(dst, 'w') as f:
        json.dump(data, f, ensure_ascii=False)

    pages = data['document']['children']
    write_screen_index()
    size = os.path.getsize(dst) / 1024 / 1024
    print(f"«{data.get('name')}» · изменён {data.get('lastModified')}")
    print(f'{dst} — {size:.1f} МБ')
    print('страницы:')
    for p in pages:
        frames = sum(1 for c in (p.get('children') or []) if c['type'] == 'FRAME')
        print(f"  {p['id']:8} {p['name']}  ({len(p.get('children') or [])} узлов, {frames} кадров)")


if __name__ == '__main__':
    main()
