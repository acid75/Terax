# Android phase 3 implementation plan

**Goal:** Implement the approved Android handoff, screens 01/03/05/06/07/08.
**Architecture:** Presentation widgets consume the existing controller and library. Only library permission/folder metadata is exposed; transfer and BLE remain untouched.
**Spec:** design/terax-handoff/SPEC.md
**Tech Stack:** Flutter, existing services, supplied tokens and local fonts.

- [x] Regression first: inline search preserves library and closes cleanly; day grouping; readable empty photos vs denied permission; Android settings full-page and deduplicated peers.
- [x] LibraryBrowser: inline controls, grouped 3-column slivers, scroll pagination, session-dismissable gesture help, document root chips and real breadcrumbs. LibraryService retains UI metadata only.
- [x] Home: Android-specific header/glow and preview, existing controller send and selection callbacks, back navigation restores library. Leave Windows branch intact.
- [x] Pairing: full-screen Android presentation sharing existing connect method and scanner; first-time entry; camera and code errors with fallback. Windows dialog retained.
- [x] Settings: full Android page using same controller actions, dedup by fingerprint, network tucked away, reception, optional Bluetooth and permissions. Do not introduce a fabricated BLE state or timeout cancellation.
- [x] Validate real gesture flow, small viewport/text200, inline search/folder navigation and pairing cancel; render actual Android widgets at 360/412 and compare reference PNGs. Run analyze, full tests and release builds.

Constraints: no new transport/protocol/BLE/pairing authorization logic. No queue, multi-send, persistent history, background Android service. UI never invents access, proximity, integrity, document reading or file counts. New widgets use Terax tokens. Transfer card choreography belongs to phases 5/6.

## Decisiones y evidencia

El alcance y las diferencias visuales quedan registrados en docs/ui/handoff-phase-3.md. Se completó la presentación de seis vistas; la coreografía y las tarjetas de transferencia conservan sus fases 5/6. La selección parcial se condiciona a la API real del sistema. Bluetooth lento se representa en UI sin alterar el servicio. Validación: 70 pruebas, analyzer, 12 capturas y builds release Android/Windows. Revisión independiente con corrección de los dos hallazgos de escalado.
