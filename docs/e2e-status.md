# E2E Status

Last local verification: 2026-05-20

## Automated

- `swift test`: passing, 23 tests.
- Unicode bullet glyphs like `• Item` convert to rich unordered list items for Superhuman-compatible output.
- `./script/build_and_run.sh --verify`: app builds, signs for local development, launches, and registers the hotkey.

## Manual App Checks

- Slack: passed in a self-DM composer.
- Superhuman: passed in a new email compose body.
- ChatGPT in Chrome: passed with Markdown preserved as plain text in the composer.
- Google Docs in Chrome: passed in a disposable document, including heading, bold, italic, code, bullets, numbered list, and quote formatting.
- Unsupported apps: safe no-op path verified.

## Privacy Checks

- Selected text is not written to diagnostics.
- The previous clipboard is restored after formatting.
