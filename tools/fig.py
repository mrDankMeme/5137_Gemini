"""Работа с локальным дампом Figma (.design/file.json)."""
import json, os, functools

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Путь можно подменить: удобно смотреть чужой дамп, не подкладывая его в проект.
DUMP = os.environ.get('FIGMA_DUMP') or os.path.join(ROOT, '.design', 'file.json')

@functools.lru_cache(maxsize=1)
def raw():
    return json.load(open(DUMP))


@functools.lru_cache(maxsize=1)
def doc():
    """Корень документа в едином виде.

    Дамп бывает двух видов. REST (`/v1/files`) кладёт дерево в `document`.
    Плагин выгружает страницы списком в `pages` — им пользуемся, когда REST
    упирается в лимит: плагин работает внутри Figma и квоты не тратит.
    """
    data = raw()
    if 'document' in data:
        return data['document']
    return {'id': '0:0', 'name': data.get('name', ''), 'type': 'DOCUMENT',
            'children': data.get('pages') or []}


def is_plugin_dump():
    return 'document' not in raw()


def text_style(n):
    """Стиль текста одинаково для обоих форматов.

    REST держит его в `style`, плагин — прямо на узле, причём межбуквенное
    расстояние и интерлиньяж приходят объектами `{value, unit}`, а не числами.
    """
    if 'style' in n:
        return n['style']

    size = n.get('fontSize') or 0

    def pixels(v):
        """Figma задаёт трекинг и интерлиньяж и в пикселях, и в процентах.
        REST отдаёт уже пиксели, плагин — как в файле, поэтому проценты
        пересчитываем сами: без этого −2% превращались в «−2 pt» и сверка
        со стилями приложения расходилась в разы."""
        if not isinstance(v, dict):
            return v
        unit = v.get('unit')
        if unit == 'AUTO':
            return None
        value = v.get('value')
        if value is None:
            return None
        return value / 100 * size if unit == 'PERCENT' else value

    return {
        'fontSize': n.get('fontSize'),
        'fontWeight': n.get('fontWeight'),
        'letterSpacing': pixels(n.get('letterSpacing')),
        'lineHeightPx': pixels(n.get('lineHeight')),
        'textAlignHorizontal': n.get('textAlignHorizontal', ''),
    }


def corner_radius(n):
    """Скругление: число, строка «a/b/c/d» для разных углов или None."""
    corners = [n.get(k) for k in ('topLeftRadius', 'topRightRadius',
                                  'bottomRightRadius', 'bottomLeftRadius')]
    if any(c is not None for c in corners):
        values = [0 if c is None else c for c in corners]
        if len(set(values)) == 1:
            return values[0] or None
        return '/'.join(str(int(v)) if float(v) == int(v) else f'{v:.1f}' for v in values)

    radius = n.get('cornerRadius')
    # Плагин отдаёт «__MIXED__», когда углы разные, а поштучных значений нет.
    if radius == '__MIXED__':
        return None
    if radius is None and n.get('rectangleCornerRadii'):
        return '/'.join(str(int(r)) for r in n['rectangleCornerRadii'])
    return radius

@functools.lru_cache(maxsize=1)
def index():
    """id -> (node, parent_id)"""
    idx = {}
    def walk(n, parent=None):
        idx[n['id']] = (n, parent)
        for c in n.get('children') or []:
            walk(c, n['id'])
    walk(doc())
    return idx

def node(nid):
    return index()[nid][0]

def hexcolor(c, opacity=None):
    r, g, b = (round(c.get(k, 0) * 255) for k in ('r', 'g', 'b'))
    a = c.get('a', 1) if opacity is None else opacity
    s = '#%02X%02X%02X' % (r, g, b)
    return s if abs(a - 1) < 0.005 else s + ' %d%%' % round(a * 100)

def paint_desc(p):
    if not p.get('visible', True):
        return None
    t = p.get('type')
    if t == 'SOLID':
        return hexcolor(p['color'], p.get('opacity', 1))
    if t and t.startswith('GRADIENT'):
        stops = [hexcolor(s['color']) + '@' + str(round(s['position'], 2)) for s in p.get('gradientStops', [])]
        return t + '(' + ', '.join(stops) + ')'
    if t == 'IMAGE':
        return 'IMAGE(%s)' % p.get('imageRef', '')[:8]
    return t


# ─── доступ к API ────────────────────────────────────────────────────────────
# Ключ файла живёт в одном месте, а не копией в каждом скрипте: макет
# пересоздаётся дубликатом (у команды на оригинал только просмотр), и с каждым
# дубликатом ключ меняется. Порядок: переменная окружения → .design/key.
import urllib.request, urllib.error, urllib.parse, gzip, time

KEYFILE = os.path.join(ROOT, '.design', 'key')
TOKENFILE = os.path.expanduser('~/.config/figma/token')


def token():
    try:
        return open(TOKENFILE).read().strip()
    except FileNotFoundError:
        raise SystemExit(f'нет токена: {TOKENFILE}')


def key():
    env = os.environ.get('FIGMA_FILE_KEY')
    if env:
        return env.strip()
    try:
        return open(KEYFILE).read().strip()
    except FileNotFoundError:
        raise SystemExit(
            'не задан ключ файла Figma.\n'
            f'  echo <ключ> > {KEYFILE}\n'
            '  либо FIGMA_FILE_KEY=<ключ> python3 tools/...'
        )


def api(path, params=None, timeout=900):
    """GET к Figma. На 429 ждёт Retry-After, но только если ждать разумно:
    лимит на /v1/files и /v1/images отдаётся сутками, и молча висеть сутки
    в терминале — хуже, чем сказать об этом вслух."""
    url = 'https://api.figma.com' + path
    if params:
        url += '?' + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={'X-Figma-Token': token(), 'Accept-Encoding': 'gzip'})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                raw = r.read()
                if r.headers.get('Content-Encoding') == 'gzip':
                    raw = gzip.decompress(raw)
                return json.loads(raw)
        except urllib.error.HTTPError as error:
            if error.code != 429 or attempt == 4:
                raise
            wait = int(error.headers.get('Retry-After') or 30)
            if wait > 600:
                raise SystemExit(
                    f'Figma: лимит на {path} держится ещё {wait / 3600:.1f} ч.\n'
                    'Квота считается по файлу — сделай свежий дубликат макета\n'
                    f'и положи его ключ в {KEYFILE}.'
                )
            print(f'  429 — ждём {wait} с', flush=True)
            time.sleep(wait)
    raise RuntimeError('лимит запросов не отпустил')
