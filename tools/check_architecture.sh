#!/usr/bin/env bash
# Проверка архитектуры хост-приложения теми же правилами, что платформа
# применяет к себе и к BroadAppTemplate (Scripts/check_architecture.sh).
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
# Путь к ripgrep не зашиваем намертво: на машинах без homebrew бинарник лежит
# в другом месте, и проверка падала с «не удалось выполнить проверку» — то есть
# обязательный перед пушем шаг выглядел сломанным, а не пропущенным.
# Порядок сохраняет прежнее поведение: сначала homebrew, потом PATH.
if [[ -z "${RG:-}" ]]; then
    if [[ -x /opt/homebrew/bin/rg ]]; then
        RG=/opt/homebrew/bin/rg
    else
        RG="$(command -v rg || true)"
    fi
fi
if [[ -z "$RG" ]]; then
    echo "не найден ripgrep (rg). Установите его или задайте RG=<путь>." >&2
    exit 2
fi
source_root="Gemini"
violations=0

check() {
    local description="$1"; local pattern="$2"; shift 2
    local output; local status=0
    output="$("$RG" -n "$@" "$pattern" "$source_root")" || status=$?
    if [[ "$status" == 0 ]]; then
        echo "✗ $description"
        echo "$output" | sed 's/^/    /' | head -12
        local total; total=$(echo "$output" | wc -l | tr -d ' ')
        [[ "$total" -gt 12 ]] && echo "    … всего $total"
        violations=$((violations + 1))
    elif [[ "$status" != 1 ]]; then
        echo "не удалось выполнить проверку: $description"; exit "$status"
    fi
}

check "Domain и Data не импортируют SwiftUI" \
    '^[[:space:]]*import[[:space:]]+SwiftUI' \
    --glob '**/Domain/**/*.swift' --glob '**/Data/**/*.swift'

check "Domain не импортирует UI, трекинг, коммерцию и вендорские SDK" \
    '^[[:space:]]*import[[:space:]]+(Adapty|AppKit|AppTrackingTransparency|StoreKit|StoreKitTest|SwiftUI|UIKit|WebKit)' \
    --glob '**/Domain/**/*.swift'

check "Presentation не импортирует Adapty и StoreKit" \
    '^[[:space:]]*import[[:space:]]+(Adapty|StoreKit)' \
    --glob '**/Presentation/**/*.swift'

check "View не резолвит зависимости" \
    'resolver\.resolve[[:space:]]*\(' --glob '**/*View*.swift'

check "Системные шрифты задаются только в файле токенов" \
    '\.system[[:space:]]*\(' --glob '**/*.swift' --glob '!**/*Tokens.swift'

check "Размеры во вью берутся из токенов, а не из чисел" \
    '(?s)\.frame\([^)]{0,180}\b(width|height|minWidth|maxWidth|minHeight|maxHeight):[[:space:]]*[1-9][0-9]*(\.[0-9]+)?\b' \
    --pcre2 --multiline --glob '**/Presentation/**/*.swift'

check "В онбординге нет Rate Us и запроса отзыва" \
    '(?i)\b(rate[[:space:]_-]*us|request[[:space:]_-]*review|SKStoreReviewController|AppStore\.requestReview)\b' \
    --pcre2 --glob '**/Onboarding*/**/*.swift'

check "Системный запрос отзыва живёт только в ReviewAdapter" \
    '(requestReview[[:space:]]*\(|SKStoreReviewController|AppStore\.requestReview)' \
    --glob '**/*.swift' --glob '!**/*ReviewAdapter.swift'

check "ATT-API живёт только в платформе" \
    '\b(AppTrackingTransparency|ATTrackingManager)\b' --glob '**/*.swift'

check "UserDefaults напрямую не используется" \
    '\b(UserDefaults|NSUserDefaults|CFPreferences[A-Za-z]*)\b' --glob '**/*.swift'

check "Вывод в консоль запрещён — только BroadLoggerProtocol" \
    '(^|[^A-Za-z0-9_.])((Swift\.)?(print|debugPrint|dump)|NSLog)[[:space:]]*\(' --glob '**/*.swift'

check "Устаревшие os_log и signpost запрещены" \
    '\b(os_log|os_logv|os_signpost|OSSignposter)\b' --glob '**/*.swift'

check "Сырые описания ошибок не выходят наружу" \
    '(\.localizedDescription\b|String[[:space:]]*\([[:space:]]*describing:[[:space:]]*error\b)' --glob '**/*.swift'

check "В UI пейвола нет захардкоженных цен" \
    '(?i)["\x27][^"\x27\r\n]{0,80}((\$|€|£|₽|USD|EUR|RUB)[[:space:]]*[0-9]|[0-9][[:space:]]*(€|£|₽|USD|EUR|RUB))' \
    --pcre2 --glob '**/Paywall*/**/*.swift'

check "В UI пейвола нет захардкоженных идентификаторов продуктов" \
    '(?i)(weekly|monthly|yearly|lifetime)[._-][A-Za-z0-9._-]+' --glob '**/Paywall*/**/*.swift'

echo
if [[ "$violations" == 0 ]]; then
    echo "архитектура: нарушений нет"
else
    echo "архитектура: нарушений — $violations"
fi
exit 0
