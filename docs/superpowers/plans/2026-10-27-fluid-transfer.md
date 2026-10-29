# Terax Fluid Transfer Implementation Plan

> **For agentic workers:** Execute independent BLE/library tasks in parallel under dispatching-parallel-agents; parent implements protocol/controller/UI and integrates.

**Goal:** Biblioteca propia con gestos de borde, animación de recepción coordinada, apertura de documentos y corrección BLE demostrable.

**Architecture:** Mantener Flutter/TLS y confianza persistente. Biblioteca aislada de plataforma. Oferta de transferencia autenticada precede a hash/upload y reserva receptor por ID. UI animada interpreta eventos reales.

**Tech Stack:** Flutter/Dart, photo_manager, SAF Android nativo, WinRT manufacturer advertisements, HTTPS/SHA-256.

**Spec:** docs/superpowers/specs/2026-10-27-fluid-transfer-design.md

## Global constraints
- Mantener autorización inicial única y claves protegidas; no simular cercanía.
- No abrir ejecutables automáticamente ni publicar datos de usuarios.
- Conservar límites de tamaño y archivos sin sobrescritura.
- Movimiento reducido y alternativa mediante botón.

## Review focus
- Oferta reservada que no sube: cancelar/caducar y liberar recepción.
- Emisor/receptor rápidos: ambas animaciones deben alcanzar a verse, sin confirmar integridad antes de tiempo.
- Permiso de fotos/carpeta denegado: estado útil, sin abrir selectores por archivo.
- Desconexión o cambio de identidad: no revivir destinos olvidados.
- Windows no anuncia: presentar error específico, no un bucle de Preparando.

## Tasks
- [x] BLE: pruebas de payload y filtrado, anuncio permitido, diagnóstico nativo y cierre seguro.
- [x] Biblioteca: fotos paginadas y documentos SAF/Windows; pruebas reales de navegación y lectura.
- [x] Transporte: prueba roja de oferta anterior a bytes, reservas, cancelación y expiración; implementar y verificar.
- [x] Controlador: selección por biblioteca, fases visuales y apertura de documentos; probar límites/política.
- [x] UI: biblioteca, vista previa con swipe, arrastre a borde, lienzo receptor desde abajo y ajustes.
- [x] Integrar, revisar, probar, compilar, empaquetar y documentar límites físicos.
