# Formatter

Formatter is a small macOS menu bar app that reformats selected Markdown-like text for the app you are already using.

The original use case is simple: copy Markdown from an AI coding tool, paste it into Slack, select the pasted text, press a hotkey, and turn it into native-looking Slack formatting without rewriting the words.

## What It Does

- Formats selected text only.
- Preserves the text content.
- Uses deterministic formatting rules by default.
- Converts Markdown structure into rich pasteboard output where the target app supports it.
- Keeps Markdown as plain text for ChatGPT.
- Optionally uses a local Ollama model only as a fallback for ambiguous Markdown.
- Validates local-model output before pasting so the selected text is not rewritten.
- Restores your previous clipboard after formatting.
- Logs operational events only, not selected text.

## Supported Targets

- Slack
- Superhuman
- ChatGPT in Chrome
- Google Docs in Chrome
- Common browser editors in Chrome or Safari

Unsupported apps fail with a safe no-op.

## How Formatting Works

Formatter is rule-based first. For normal Markdown, it parses headings, bold, italic, inline code, fenced code blocks, blockquotes, bullets, numbered lists, spacing, and line breaks without using an LLM.

If the Markdown appears ambiguous, such as an unclosed code fence or unmatched inline marker, Formatter can ask a locally installed Ollama model to produce an HTML fragment. That fallback stays on your machine and is accepted only if the plain-text content still matches what Formatter expected. If Ollama is unavailable or the output changes the text, Formatter leaves the selection alone.

## Requirements

- macOS 14 or newer
- Xcode Command Line Tools
- Accessibility permission for Formatter
- Optional: Ollama, for local-model fallback on ambiguous Markdown

Install Xcode Command Line Tools if needed:

```sh
xcode-select --install
```

## Install From Source

Clone and build:

```sh
git clone https://github.com/Jdjohnson/formatter.git
cd formatter
./script/build_and_run.sh
```

The app bundle is created at:

```text
dist/Formatter.app
```

To install it into Applications:

```sh
rm -rf /Applications/Formatter.app
cp -R dist/Formatter.app /Applications/Formatter.app
open /Applications/Formatter.app
```

## First Run Permissions

Formatter needs Accessibility permission so it can copy the selected text, replace it, and restore your clipboard.

1. Open System Settings.
2. Go to Privacy & Security > Accessibility.
3. Turn on Formatter.
4. If the hotkey does not fire, also enable Formatter under Privacy & Security > Input Monitoring.
5. Quit and reopen Formatter if macOS asks you to.

Only grant permission to the Formatter app you built or installed.

## Use

1. Paste Markdown-like text into Slack, Superhuman, Google Docs, or another supported editor.
2. Select the text you want to format.
3. Press `Control + Option + Space`.

You can also click the Formatter menu bar icon and choose `Format Selection Now`.

## Configure The Hotkey

Open the Formatter menu bar item, choose `Settings...`, then click the hotkey recorder and press the shortcut you want.

The default hotkey is:

```text
Control + Option + Space
```

## Build, Test, And Run

Run tests:

```sh
swift test
```

Build and launch:

```sh
./script/build_and_run.sh
```

Build, launch, and verify the process starts:

```sh
./script/build_and_run.sh --verify
```

Trigger formatting without pressing the hotkey, useful for local debug testing when the app has been launched with `FORMATTER_ENABLE_EXTERNAL_TRIGGER=1`:

```sh
./script/trigger_format.sh
```

## Distribution

For local source builds, the commands above are enough.

For a public binary release outside the Mac App Store, Apple requires a Developer ID Application certificate, hardened runtime signing, notarization, and stapling. This project includes a release script for maintainers:

```sh
./script/package_release.sh --notary-profile FormatterNotary
```

See [docs/distribution.md](docs/distribution.md) for the full release checklist.

## Privacy

Formatter uses the macOS pasteboard while formatting, then restores the previous clipboard contents after a short delay. Diagnostics record categories such as target app, success, permission missing, or unsupported app. Diagnostics do not record selected text.

## License

MIT License. See [LICENSE](LICENSE).
