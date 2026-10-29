# Windows phase 4 implementation plan

**Goal:** Apply the approved Windows receiving/sending/settings design.
**Spec:** design/terax-handoff/SPEC.md, screens 09/11 and source HTML.
**Architecture:** Windows shell and dedicated receiver/browser/settings presentation consume AppController and LibraryService. No transport, native effects, pairing authorization or BLE changes.

- [x] Tests first: truthful unavailable/paused reception, session activity, Ctrl+F, row selection and Ctrl+Enter single-send, oversize rejection, responsive layout.
- [x] WindowsHome shell: 232px sidebar at desktop size, destination header, real receipt path, 340px history at 1280x800. Narrow window uses drawer/stacked panels.
- [x] WindowsBrowser: existing folder service, local roots and session-only added roots, file metadata table, keyboard navigation, real image/document representation and send guard.
- [x] WindowsSettings: scrollable dialog, deduplicated devices, existing pairing QR/code actions, network details, reception, auto-open, desktop effect toggle/test and reset confirmation.
- [x] Home dispatches Android vs Windows by theme platform; remove legacy Windows UI after replacement, preserve transfer scene until phases 5/6.
- [x] Render actual widgets at 1280x800, compare PNGs, test narrow windows/text200, full tests/analyze, release builds, portable archive.

**Files:** lib/ui/windows_home.dart, windows_browser.dart, windows_settings.dart; lib/ui/home.dart, settings.dart; lib/theme/terax_theme.dart. LibraryService may expose current location metadata only for folder selection. Tests in test/windows_redesign_test.dart and existing Home/gesture regressions.

**Decisions:** Window size does not change operating system identity: a narrow Windows window still has Windows navigation. Empty receipt state must not claim a server is ready when it is absent. History is the existing session list (10 visible); never persisted. New status cards/motion remain phase 5/6.

## Evidencia y decisiones finales

Se usó la fase 4 del handoff sin reabrir decisiones de transporte. La pantalla Windows conserva su identidad a cualquier tamaño; paneles se adaptan en ventanas estrechas. Se corrigió el atajo global Ctrl+F señalado por revisión independiente y se añadieron pruebas de entrada desde el menú y navegación real con Enter. Ver docs/ui/handoff-phase-4.md. Resultado: 78 pruebas, analyzer limpio, cuatro capturas y builds release.
