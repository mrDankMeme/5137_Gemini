# 5137 Gemini

iPhone-приложение: чат с ИИ, генерация изображений и видео. iOS 18+, SwiftUI.
Построено на [BroadApps iOS Platform](https://github.com/BroadApps-official/BroadCore)
(ветка `vers_niiaz`), подключённой как Swift Package.

Источник интерфейса — [Figma «5137 - Gemini (Анастасия, 29.07.2026)»](https://www.figma.com/design/esPwzgWHZILar0d8oOElWv/).
Метки `no-code` на карточке Kaiten нет, значит дизайн берём из Figma.

## Как открыть проект

`.xcodeproj` в репозитории **не хранится** — он генерируется из `project.yml`:

```bash
brew install xcodegen   # один раз
xcodegen generate
open Gemini.xcodeproj
```

### Доступ к приватному пакету платформы

`BroadCore` — приватный репозиторий, и SPM не умеет спросить логин по HTTPS
(`fatal: could not read Username for 'https://github.com'`). Один раз настройте
git подтягивать репозитории организации по SSH:

```bash
git config --global url."git@github.com:BroadApps-official/".insteadOf \
  "https://github.com/BroadApps-official/"
```

## Сборка

```bash
xcodebuild -project Gemini.xcodeproj -scheme Gemini \
  -destination 'generic/platform=iOS' -configuration Release \
  build CODE_SIGNING_ALLOWED=NO
```

Результат проверяйте по строке `BUILD SUCCEEDED`, а не по коду возврата обёртки.

> На машине разработчика стоит только Xcode 27 beta, а Codemagic собирает
> `xcode: latest`. Локальный успех **не гарантирует** зелёный CI.

## Отладка экранов

В Debug любой экран открывается напрямую, минуя маршрут запуска:

```bash
xcrun simctl launch <device> com.broadapps.gemini5137 -route paywall
```

Значения `-route`: `launch`, `onboarding`, `paywall`, `main`. Отдельный аргумент
`-seed` наполняет экраны данными: `chat`, `menu`, `settings`, `library`,
`model-picker`, `voice`, `tokens-paywall`, `special-offer`, `rate-us` и другие.
В Release этого кода нет.

## Структура

```
Gemini/
  Application/    точка входа, сборка зависимостей, корневой маршрут
  Core/
    Configuration/  настройки приложения и файл временных значений
    DesignSystem/   цвета, типографика и общие компоненты из Figma
  Features/       экраны, каждый со своей ViewModel
  Resources/      Info.plist, ассеты
docs/
  specs/          спецификация: карта экранов, сверка функций с backend
tools/            разбор дампа Figma и выгрузка ассетов
```

## Временные данные

Bundle ID, ключ Adapty, продукты и ссылки пока **чужие** — взяты из reference-проекта
`Claude232`, потому что документ 5137 в Kaiten ещё не заполнен. Все они собраны
в одном файле `Gemini/Core/Configuration/DevelopmentConfiguration.swift` и помечены.

Пока это так, настоящие покупки, восстановление и RU-платежи не запускаются.
Что именно заменить перед релизом — в `docs/specs/2026-08-20-gemini-design.md`.

## Дизайн

Работа с Figma идёт через REST API, а не через MCP: MCP требует edit-доступа к файлу,
а у команды он только на просмотр. Нужен личный токен в `~/.config/figma/token`.

```bash
python3 tools/figma_png.py        # выгрузить все экраны в .design/png/
python3 tools/figma_spec.py <ключ-экрана>   # точная геометрия экрана
python3 tools/figma_assets.py     # ассеты в Assets.xcassets
```

Дамп файла и рендеры лежат в `.design/` и в git не попадают.
