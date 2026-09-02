"""Раскладывает эталонные PNG экранов из выгрузки плагина в `.design/png/`.

Нужно, потому что REST-ручка `/v1/images` лимитирована по файлу и уходит в 429
на сутки. Плагин рисует те же кадры изнутри Figma, квоту не тратит, и после
этого `compare.py` может складывать макет со снимком симулятора бок о бок.

Числами сверить можно не всё: плотность свечения, градиенты и составные
эффекты видны только на картинке.

    python3 tools/figma_screens.py ~/Downloads/figma-screens.json
"""
import base64
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

OUT = os.path.join(fig.ROOT, '.design', 'png')


def main():
    if len(sys.argv) < 2:
        raise SystemExit('укажите путь к выгрузке: python3 tools/figma_screens.py <файл>')

    data = json.load(open(sys.argv[1]))
    index = {s['id']: s['key'] for s in json.load(open(os.path.join(fig.ROOT, '.design', 'screens.json')))}
    os.makedirs(OUT, exist_ok=True)

    saved, skipped, failed = 0, [], []
    for node_id, item in data.items():
        if item.get('error'):
            failed.append((item.get('name'), item['error']))
            continue
        key = index.get(node_id)
        if not key:
            # Кадр есть в выгрузке, но не попал в индекс: его ширина не 402,
            # либо индекс собран с другого дампа.
            skipped.append(item.get('name'))
            continue
        with open(os.path.join(OUT, key + '.png'), 'wb') as f:
            f.write(base64.b64decode(item['png']))
        saved += 1

    print(f'сохранено экранов: {saved} -> {OUT}')
    if skipped:
        print(f'не нашлось в индексе: {len(skipped)} ({", ".join(skipped[:5])}…)')
    if failed:
        print(f'не выгрузились: {len(failed)}')
        for name, err in failed[:5]:
            print(f'   {name}: {err[:60]}')


if __name__ == '__main__':
    main()
