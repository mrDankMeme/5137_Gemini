"""Собирает иконку приложения из фирменной «искры».

Макет (страница «📲 appicon & preview AppStore») задаёт иконку как квадрат 1024
с вектором 611×610 по центру. Рендер этого кадра через Figma сейчас недоступен
(лимит /v1/images), поэтому звезда строится той же геометрией, что и
`SparkleShape` в коде: четыре квадратичные кривые с общей вогнутостью.

Если ASO пришлёт финальный ассет — просто заменить PNG, скрипт больше не нужен.
"""
import os
from PIL import Image, ImageDraw

SIZE = 1024
SPARKLE = 611          # размер вектора в макете
CONCAVITY = 0.82       # та же вогнутость, что в SparkleShape
BACKGROUND = (218, 232, 255)   # #DAE8FF
FOREGROUND = (31, 59, 155)     # #1F3B9B
OUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'Gemini', 'Resources', 'Assets.xcassets', 'AppIcon.appiconset', 'AppIcon.png',
)


def quad(p0, control, p1, steps=160):
    """Точки квадратичной кривой Безье."""
    points = []
    for index in range(steps + 1):
        t = index / steps
        inv = 1 - t
        x = inv * inv * p0[0] + 2 * inv * t * control[0] + t * t * p1[0]
        y = inv * inv * p0[1] + 2 * inv * t * control[1] + t * t * p1[1]
        points.append((x, y))
    return points


def sparkle(center, radius):
    """Четырёхлучевая звезда: лучи задаются кривыми с контрольной точкой у центра."""
    cx, cy = center
    offset = radius * (1 - CONCAVITY)
    top, right = (cx, cy - radius), (cx + radius, cy)
    bottom, left = (cx, cy + radius), (cx - radius, cy)

    return (
        quad(top, (cx + offset, cy - offset), right)
        + quad(right, (cx + offset, cy + offset), bottom)
        + quad(bottom, (cx - offset, cy + offset), left)
        + quad(left, (cx - offset, cy - offset), top)
    )


def main():
    # Рисуем с четырёхкратным запасом и уменьшаем — так края получаются гладкими.
    scale = 4
    image = Image.new('RGB', (SIZE * scale, SIZE * scale), BACKGROUND)
    draw = ImageDraw.Draw(image)
    draw.polygon(
        sparkle((SIZE * scale / 2, SIZE * scale / 2), SPARKLE * scale / 2),
        fill=FOREGROUND,
    )
    image.resize((SIZE, SIZE), Image.LANCZOS).save(OUT)
    print('иконка сохранена:', OUT)


if __name__ == '__main__':
    main()
