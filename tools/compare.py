"""Складывает макет и снимок приложения рядом — для сверки вёрстки."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fig
from PIL import Image

# Куда сессия складывает снимки симулятора. Абсолютный путь тут не живёт:
# он привязан к машине и id сессии, а прошлый захардкоженный путь от другой
# машины приводил к тому, что скрипт молча печатал «пропуск» на все экраны
# и выглядел работающим, ничего не сверяя.
SHOTS = os.environ.get('SHOTS') or os.path.join(fig.ROOT, '.design', 'shots')
OUT = os.path.join(SHOTS, 'pairs')
DESIGN = os.path.join(fig.ROOT, '.design', 'png')

PAIRS = {
    'onboarding':     'onbording-paywall--onbording1',
    'paywall':        'onbording-paywall--paywall',
    'tokens-paywall': 'onbording-paywall--paywall-token',
    'special-offer':  'onbording-paywall--special-offer',
    'rate-us':        'onbording-paywall--rate-us',
    'home':           'main--home',
    'model-picker':   'main--home-10',
    'voice':          'main--home-16',
    'attachments':    'main--home-15',
    'chat':           'main--chat-12',
    'tokens':         'main--chat-23',
    'limit':          'main--chat-24',
    'error':          'main--chat-22',
    'menu':           'menu--menu',
    'history':        'menu--menu-4',
    'library':        'menu--menu-5',
    'settings':       'settings--settings',
    'generation':     'main--photo-3',
    'banner':         '--home',
    'update':         '--settings',
}

def main():
    if not os.path.isdir(SHOTS):
        raise SystemExit(f'нет папки со снимками: {SHOTS}\n'
                         'положи туда PNG симулятора или задай SHOTS=<путь>')
    os.makedirs(OUT, exist_ok=True)
    height = 1400
    made = 0
    for shot, design in PAIRS.items():
        shot_path = os.path.join(SHOTS, shot + '.png')
        design_path = os.path.join(DESIGN, design + '.png')
        if not (os.path.exists(shot_path) and os.path.exists(design_path)):
            print('пропуск:', shot)
            continue

        left = Image.open(design_path).convert('RGB')
        right = Image.open(shot_path).convert('RGB')
        left = left.resize((int(left.width * height / left.height), height))
        right = right.resize((int(right.width * height / right.height), height))

        gap = 16
        canvas = Image.new('RGB', (left.width + gap + right.width, height), (40, 40, 40))
        canvas.paste(left, (0, 0))
        canvas.paste(right, (left.width + gap, 0))
        canvas.save(os.path.join(OUT, shot + '.png'))
        made += 1
        print('готово:', shot)

    if not made:
        raise SystemExit(f'ни одной пары не собрано — проверь {SHOTS} и {DESIGN}')

if __name__ == '__main__':
    main()
