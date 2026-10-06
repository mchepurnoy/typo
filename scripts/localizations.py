#!/usr/bin/env python3
"""Source of truth for Typo's interface translations; writes Sources/Typo/Resources/Localizable.xcstrings.

Usage: scripts/localizations.py

Keys are the English strings as they appear in the code (SwiftUI interpolations become %@ / %lld).
Edit TRANSLATIONS here, run the script, and commit both. LocalizationTests checks that every
string in the code has a Russian translation and that no key is unused.
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "Sources" / "Typo" / "Resources" / "Localizable.xcstrings"

CREDITS_EN = (
    "Free software under the GNU GPL v3 (GPL-3.0-only).\n\n"
    "Language data derived from the Leipzig Corpora Collection (eng_news_2024_1M, rus_news_2024_1M, "
    "deu_news_2024_1M, spa_news_2024_1M), Universität Leipzig, wortschatz.uni-leipzig.de, licensed under "
    "CC BY. Changes: lowercased, ё folded to е, reduced to trigram statistics and a frequency list.\n\n"
    "Words that take ё from eyo-kernel by Denis Seleznev (MIT License)."
)
CREDITS_RU = (
    "Свободная программа под лицензией GNU GPL v3 (GPL-3.0-only).\n\n"
    "Языковые данные получены из Leipzig Corpora Collection (eng_news_2024_1M, rus_news_2024_1M, "
    "deu_news_2024_1M, spa_news_2024_1M), Universität Leipzig, wortschatz.uni-leipzig.de, лицензия "
    "CC BY. Изменения: приведены к нижнему регистру, ё заменена на е, сведены к статистике триграмм "
    "и частотному словарю.\n\n"
    "Слова с буквой ё — из eyo-kernel Дениса Селезнёва (лицензия MIT)."
)

TRANSLATIONS = {
    # Menu
    "Pause Typo": "Приостановить Typo",
    "Settings…": "Настройки…",
    "About Typo": "О программе Typo",
    "Quit Typo": "Завершить Typo",
    "Set Up Permissions…": "Настроить разрешения…",
    "Language data missing: %@. Reinstall Typo.": "Нет языковых данных: %@. Переустановите Typo.",
    "Input Monitoring is off: Typo may not see what you type.":
        "Мониторинг ввода выключен: Typo может не видеть, что вы печатаете.",
    "Typo cannot watch the keyboard. Remove Typo from Privacy & Security → Accessibility and add it again.":
        "Typo не может следить за клавиатурой. Удалите Typo из «Конфиденциальность и безопасность» → "
        "«Универсальный доступ» и добавьте снова.",
    "Accessibility permission was turned off.": "Разрешение «Универсальный доступ» было выключено.",
    "Waiting for Accessibility permission…": "Ожидание разрешения «Универсальный доступ»…",
    CREDITS_EN: CREDITS_RU,
    # Onboarding
    "Set Up Typo": "Настройка Typo",
    "Typo fixes words typed in the wrong keyboard layout, like ghbdtn → привет.":
        "Typo исправляет слова, набранные не в той раскладке: ghbdtn → привет.",
    "To do that it needs two permissions. What you type stays on this Mac: it is never stored, logged or sent anywhere.":
        "Для этого нужны два разрешения. То, что вы печатаете, остаётся на этом Mac: оно нигде не "
        "сохраняется, не записывается в журналы и никуда не отправляется.",
    "Accessibility": "Универсальный доступ",
    "Lets Typo replace a mistyped word and switch the layout.":
        "Позволяет Typo заменить слово, набранное не в той раскладке, и переключить раскладку.",
    "Input Monitoring": "Мониторинг ввода",
    "Lets Typo see the keys you type, to notice a word in the wrong layout.":
        "Позволяет Typo видеть нажатые клавиши, чтобы заметить слово в неправильной раскладке.",
    "Typo is working. You can close this window.": "Typo работает. Это окно можно закрыть.",
    "Typo is running. If it does not correct anything, allow Input Monitoring too.":
        "Typo запущен. Если он ничего не исправляет, разрешите также мониторинг ввода.",
    "Typo starts working as soon as Accessibility is allowed; there is no need to relaunch it.":
        "Typo начнёт работать, как только будет разрешён универсальный доступ; перезапускать не нужно.",
    "Done": "Готово",
    "Allowed": "Разрешено",
    "Open System Settings…": "Открыть Системные настройки…",
    # Settings: tabs
    "General": "Основные",
    "Words": "Слова",
    "Excluded Apps": "Исключённые приложения",
    "Layouts": "Раскладки",
    # Settings: General
    "Launch at login": "Открывать при входе в систему",
    "Allow Typo in System Settings → General → Login Items.":
        "Разрешите Typo в Системных настройках → Основные → Объекты входа.",
    "Convert the last word": "Перевести последнее слово",
    "Double-tap %@": "Двойное нажатие %@",
    "Shift": "Shift",
    "Option": "Option",
    "Control": "Control",
    "Command": "Command",
    "Switch the keyboard layout automatically": "Переключать раскладку автоматически",
    "macOS's \"Automatically switch to a document's input source\" can undo the switch; turn it off in Keyboard settings.":
        "Настройка macOS «Автоматически переключаться на источник ввода документа» может отменить "
        "переключение; выключите её в настройках клавиатуры.",
    "Fix typos in the right layout (teh → the)": "Исправлять опечатки в правильной раскладке (превет → привет)",
    "Add ё, umlauts and accents where certain (еще → ещё, konnen → können)":
        "Расставлять ё, умлауты и акценты, где это однозначно (еще → ещё, konnen → können)",
    "Play a sound on each correction": "Звук при каждом исправлении",
    # Settings: Words
    "Add a word": "Добавить слово",
    "Add": "Добавить",
    "Exceptions": "Исключения",
    "Kept as typed, never converted. Backspace right after a correction adds the word here.":
        "Остаются как набраны и никогда не переводятся. Backspace сразу после исправления добавляет слово сюда.",
    "None yet": "Пока нет",
    "Learned words": "Выученные слова",
    "Always converted. Converting a word with the hotkey adds it here.":
        "Переводятся всегда. Перевод слова горячей клавишей добавляет его сюда.",
    "Not converted to %@": "Не переводится в «%@»",
    "Remove": "Удалить",
    # Settings: Excluded Apps
    "Typo works in every app.": "Typo работает во всех приложениях.",
    "Add App…": "Добавить приложение…",
    "Typo ignores these apps entirely.": "В этих приложениях Typo ничего не делает.",
    # Settings: Layouts
    "Language data missing": "Нет языковых данных",
    "Not supported": "Не поддерживается",
    "Nothing to correct: enable a supported layout of another script, e.g. Russian – PC next to U.S.":
        "Нечего исправлять: включите поддерживаемую раскладку с другим алфавитом, например «Русская – ПК» "
        "вместе с U.S.",
    "Typo corrects between supported layouts of different scripts (Latin ↔ Cyrillic). Supported languages: %@.":
        "Typo исправляет между поддерживаемыми раскладками с разными алфавитами (латиница ↔ кириллица). "
        "Поддерживаемые языки: %@.",
    "English": "английский",
    "Russian": "русский",
    "German": "немецкий",
    "Spanish": "испанский",
}

# Plural strings: key -> (English one/other, Russian one/few/many/other)
PLURALS = {
    "After %lld corrections in a row": (
        {"one": "After %lld correction in a row", "other": "After %lld corrections in a row"},
        {"one": "После %lld исправления подряд", "few": "После %lld исправлений подряд",
         "many": "После %lld исправлений подряд", "other": "После %lld исправления подряд"},
    ),
}


def unit(value: str) -> dict:
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(forms: dict) -> dict:
    return {"variations": {"plural": {form: unit(value) for form, value in forms.items()}}}


def main() -> None:
    strings = {key: {"localizations": {"ru": unit(ru)}} for key, ru in TRANSLATIONS.items()}
    for key, (en, ru) in PLURALS.items():
        strings[key] = {"localizations": {"en": plural(en), "ru": plural(ru)}}
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(strings)} strings)")


if __name__ == "__main__":
    main()
