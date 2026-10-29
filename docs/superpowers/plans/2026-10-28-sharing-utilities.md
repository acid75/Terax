# Sharing utilities implementation plan

User selected the complete package: Downloads/file picker, text/links, explicit clipboard actions, Android ACTION_SEND/SEND_MULTIPLE, durable local history, sequential file queue. This supersedes the old UI-only restriction on these named features. Retain transport endpoints/authorization/Bluetooth and handoff theme.

Design: messages are bounded UTF-8 Terax message envelope files sent through the existing verified file transport. Older receivers save an ordinary file; new receivers decode only verified files, never execute contents, and expose Copy/Open HTTP(S) explicitly. No automatic clipboard read/write or remote link launch. File queues are sequential, foreground, pause on failure and retain pending entries. History records completed transfers and can be cleared without deleting files.

Files/contracts:
- Android worker: MainActivity.kt + AndroidManifest.xml + new lib/sharing/android_share_bridge.dart + focused bridge tests. Pick individual files through OPEN_DOCUMENT; receive share intents including cold start; existing materialization/read permissions; openLink only http(s). Primary integrates into Home/controller.
- History worker: new lib/transfer/history_entry.dart, history_store.dart and tests; primary moves/reexports HistoryEntry and integrates load/save/clear.
- Queue worker: new lib/transfer/transfer_queue.dart and tests. Independent serial runner and outcome model; primary integrates callback to verified c.sendLibraryItem and UI panel.
- Primary: message payload codec/store, composer/received content, AppController hooks, Home and Windows shell actions, history page, queue panel, Windows safe openLink channel.

Checks: first failing tests for codec/bounds and feature contracts, focussed workers tests, full suite, analyzer, Android 360/412 and Windows1280 captures, release builds and new utility packages preserving prior final packages. Independent read-only review at integration.

Not included: Android background receiver/service, automatic clipboard synchronization, resumable transfers, internet/cloud relay, persisted pending queue. These require separate lifecycle/protocol work and are not prerequisites for the selected package.


## Completed 2026-10-28

All selected utilities integrated. Added the subsequently requested real file edge flight and complementary native outgoing/incoming sounds, with explicit mute controls. The queue binds its destination, combined Android shares retain both text and files, and history clearing rolls back on persistence failure. Independent integration review findings resolved. Verification: 144 tests, clean analyze, Android/Windows release builds; native versions 0.5.0 (7), unchanged existing core hashes, visual fixture pass. See docs/ui/utilities-0.5.md for usage and physical-device validation boundaries.
