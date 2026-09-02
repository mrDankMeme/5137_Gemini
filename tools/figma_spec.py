"""Печатает точную геометрию экрана из дампа Figma — для вёрстки 1:1.

Использование: python3 tools/figma_spec.py <node-id | ключ-экрана> [глубина]
Например:      python3 tools/figma_spec.py onbording-paywall--onbording1
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig

def resolve(arg):
    if ':' in arg or '-' in arg and arg[0].isdigit():
        return arg.replace('-', ':')
    screens = json.load(open(os.path.join(fig.ROOT, '.design', 'screens.json')))
    for s in screens:
        if s['key'] == arg:
            return s['id']
    raise SystemExit(f'экран не найден: {arg}')

def fmt(v):
    if v is None:
        return ''
    return str(int(v)) if float(v) == int(v) else f'{float(v):.1f}'

def describe(n, origin):
    bb = n.get('absoluteBoundingBox') or {}
    x = (bb.get('x', 0) - origin[0]) if bb else 0
    y = (bb.get('y', 0) - origin[1]) if bb else 0
    width = bb.get('width', n.get('width'))
    height = bb.get('height', n.get('height'))
    parts = [f"{fmt(width)}x{fmt(height)} @ {fmt(x)},{fmt(y)}"]

    if n.get('layoutMode') in ('HORIZONTAL', 'VERTICAL'):
        pads = [n.get(k, 0) for k in ('paddingTop', 'paddingRight', 'paddingBottom', 'paddingLeft')]
        parts.append(
            f"auto:{n['layoutMode'][:1]} gap={fmt(n.get('itemSpacing'))} "
            f"pad={'/'.join(fmt(p) for p in pads)} "
            f"align={n.get('primaryAxisAlignItems', 'MIN')}/{n.get('counterAxisAlignItems', 'MIN')}"
        )

    radius = fig.corner_radius(n)
    if radius:
        parts.append(f'radius={fmt(radius) if not isinstance(radius, str) else radius}')

    fills = [d for d in (fig.paint_desc(p) for p in (n.get('fills') or [])) if d]
    if fills:
        parts.append('fill=' + ','.join(fills))
    strokes = [d for d in (fig.paint_desc(p) for p in (n.get('strokes') or [])) if d]
    if strokes:
        parts.append(f"stroke={','.join(strokes)}·{fmt(n.get('strokeWeight'))}")

    for effect in n.get('effects') or []:
        if effect.get('visible', True):
            parts.append(f"{effect['type'].lower()}(r={fmt(effect.get('radius'))})")

    if n['type'] == 'TEXT':
        s = fig.text_style(n)
        parts.append(
            f"text[{fmt(s.get('fontSize'))}/{fmt(s.get('lineHeightPx'))} "
            f"w{s.get('fontWeight')} ls{fmt(s.get('letterSpacing'))} "
            f"{s.get('textAlignHorizontal', '')[:1]}]"
        )
        parts.append('«' + n['characters'].replace('\n', '⏎')[:48] + '»')
    return ' · '.join(parts)

def main():
    nid = resolve(sys.argv[1])
    max_depth = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    root = fig.node(nid)
    bb = root.get('absoluteBoundingBox') or {}
    origin = (bb.get('x', 0), bb.get('y', 0))

    def walk(n, depth):
        if depth > max_depth or not n.get('visible', True):
            return
        print('  ' * depth + f"{n['type'][:6]:6} {n['name'][:26]:26} " + describe(n, origin))
        for c in n.get('children') or []:
            walk(c, depth + 1)

    walk(root, 0)

if __name__ == '__main__':
    main()
