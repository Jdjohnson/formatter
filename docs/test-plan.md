# Formatter Test Plan

Use synthetic text only.

## Automated

- Markdown parsing and rich payload generation
- Plain text preservation
- Target app detection
- Pasteboard type writing and restoration
- Diagnostics privacy
- Safe ambiguity detection

## Real app checks

- First-run permission: System Settings > Privacy & Security > Accessibility must show `Formatter` enabled before live copy/paste checks can pass.
- Slack self-DM composer: paste and format, do not send
- Superhuman compose body: paste and format, do not send
- ChatGPT in Chrome: submit synthetic test message when needed
- Google Docs in Chrome: write synthetic content into a disposable doc
- Local contenteditable fixture: use for repeatable browser paste debugging
- Automated trigger: `./script/trigger_format.sh` can exercise the same formatting path when synthetic key events do not reach the global hotkey listener
