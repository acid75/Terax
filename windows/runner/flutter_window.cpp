#include "flutter_window.h"

#include <optional>
#include <cctype>
#include <limits>
#include <algorithm>
#include <iterator>
#include <shellapi.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  file_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "terax/files",
      &flutter::StandardMethodCodec::GetInstance());
  file_channel_->SetMethodCallHandler([this](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "presentIncoming") {
      const auto window = GetHandle();
      // A real offer must reveal Flutter's live edge flight, never a frozen capture.
      ShowWindow(window, IsIconic(window) ? SW_RESTORE : SW_SHOWNOACTIVATE);
      SetWindowPos(window, HWND_TOP, 0, 0, 0, 0,
          SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE | SWP_SHOWWINDOW);
      FLASHWINFO flash{sizeof(FLASHWINFO), window, FLASHW_TRAY, 3, 0};
      FlashWindowEx(&flash);
      flutter_controller_->ForceRedraw();
      result->Success(); return;
    }
    if (call.method_name() == "notifyReceived") {
      const auto* values = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
      const std::string* name = nullptr;
      if (values) {
        const auto it = values->find(flutter::EncodableValue("name"));
        if (it != values->end()) name = std::get_if<std::string>(&it->second);
      }
      if (!name || name->empty() || name->find('\0') != std::string::npos ||
          name->size() > static_cast<size_t>((std::numeric_limits<int>::max)())) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
          name->data(), static_cast<int>(name->size()), nullptr, 0);
      if (length <= 0) { result->Success(flutter::EncodableValue(false)); return; }
      std::wstring body(length, L'\0');
      if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, name->data(),
          static_cast<int>(name->size()), body.data(), length) != length) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      const auto separator = body.find_last_of(L"/\\");
      if (separator != std::wstring::npos) body.erase(0, separator + 1);
      for (auto& character : body) {
        if (character < L' ' || character == 0x7f ||
            (character >= 0x202a && character <= 0x202e) ||
            (character >= 0x2066 && character <= 0x2069)) character = L' ';
      }
      const auto window = GetHandle();
      const bool hidden = !IsWindowVisible(window) || IsIconic(window);
      result->Success(flutter::EncodableValue(hidden && !body.empty() &&
          ShowTrayNotice(L"Recibido y verificado", body)));
      return;
    }
    if (call.method_name() == "desktopWave") {
      bool reduced = false;
      if (const auto* values = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr) {
        const auto it = values->find(flutter::EncodableValue("reducedMotion"));
        if (it != values->end()) if (const auto* value = std::get_if<bool>(&it->second)) reduced = *value;
      }
      if (desktop_wave_.active()) { result->Success(flutter::EncodableValue(true)); return; }
      if (!desktop_wave_.Play(GetHandle(), reduced)) {
        result->Error("desktop_effect", desktop_wave_.error()); return;
      }
      result->Success(flutter::EncodableValue(true)); return;
    }
    if (call.method_name() == "stopDesktopWave") {
      desktop_wave_.Stop(); result->Success(); return;
    }
    if (call.method_name() == "openLink") {
      const auto* url = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
      if (!url || url->size() > 8192 || url->find_first_of("\r\n\t") != std::string::npos ||
          std::any_of(url->begin(), url->end(), [](unsigned char c) { return c < 32 || c == 127; })) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      auto prefix = url->substr(0, 8);
      std::transform(prefix.begin(), prefix.end(), prefix.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
      if (prefix.rfind("https://", 0) != 0 && prefix.rfind("http://", 0) != 0) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, url->data(), static_cast<int>(url->size()), nullptr, 0);
      if (length <= 0) { result->Success(flutter::EncodableValue(false)); return; }
      std::wstring wide(length, L'\0');
      if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, url->data(), static_cast<int>(url->size()), wide.data(), length) != length) {
        result->Success(flutter::EncodableValue(false)); return;
      }
      const auto status = reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
      result->Success(flutter::EncodableValue(status > 32)); return;
    }
    if (call.method_name() != "open") { result->NotImplemented(); return; }
    const auto* path = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
    if (!path || path->empty() || path->find('\0') != std::string::npos) {
      result->Error("invalid_path", "Ruta invalida"); return;
    }
    const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         path->data(), static_cast<int>(path->size()), nullptr, 0);
    if (length == 0) { result->Error("invalid_path", "Ruta invalida"); return; }
    std::wstring wide(length, L'\0');
    MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->data(),
                        static_cast<int>(path->size()), wide.data(), length);
    // Pass the literal path to the Windows shell API, never through cmd.exe.
    const auto status = reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
    result->Success(flutter::EncodableValue(status > 32));
  });
  proximity_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "terax/proximity",
      &flutter::StandardMethodCodec::GetInstance());
  proximity_channel_->SetMethodCallHandler([this](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
    try {
      if (call.method_name() == "stop") {
        if (ble_publisher_) ble_publisher_.Stop();
        ble_publisher_ = nullptr;
        result->Success(); return;
      }
      if (call.method_name() == "start") {
        const auto* fingerprint = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
        if (!fingerprint || fingerprint->size() != 64 || fingerprint->find_first_not_of("0123456789abcdefABCDEF") != std::string::npos) {
          result->Error("invalid_fingerprint", "Expected 64 hexadecimal characters"); return;
        }
        if (ble_publisher_) ble_publisher_.Stop();
        ble_state_ = std::make_shared<terax_ble::PublisherState>();
        ble_publisher_ = terax_ble::Create(*fingerprint, ble_state_);
        ble_publisher_.Start();
      } else if (call.method_name() != "status") { result->NotImplemented(); return; }
      result->Success(flutter::EncodableValue(terax_ble::Status(ble_publisher_, ble_state_)));
    } catch (const winrt::hresult_error& error) {
      const auto detail = winrt::to_string(error.message()) +
                          " (HRESULT=" + std::to_string(error.code().value) + ")";
      if (ble_state_) {
        std::lock_guard<std::mutex> lock(ble_state_->mutex);
        ble_state_->error = detail;
      }
      result->Error("bluetooth_unavailable", detail);
    }
  });
  sound_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "terax/sounds",
      &flutter::StandardMethodCodec::GetInstance());
  sound_channel_->SetMethodCallHandler([this](
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (call.method_name() == "stop") { transfer_sounds_.Stop(); result->Success(); return; }
    if (call.method_name() != "play") { result->NotImplemented(); return; }
    const auto* values = call.arguments() ? std::get_if<flutter::EncodableMap>(call.arguments()) : nullptr;
    const std::string* path = nullptr;
    if (values) {
      const auto it = values->find(flutter::EncodableValue("path"));
      if (it != values->end()) path = std::get_if<std::string>(&it->second);
    }
    result->Success(flutter::EncodableValue(path && transfer_sounds_.Play(*path)));
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  tray_.cbSize = sizeof(tray_);
  tray_.hWnd = GetHandle();
  tray_.uID = 1;
  tray_.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
  tray_.uCallbackMessage = WM_APP + 70;
  tray_.hIcon = LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
  wcscpy_s(tray_.szTip, L"Terax · listo para recibir");
  tray_added_ = Shell_NotifyIconW(NIM_ADD, &tray_) != FALSE;

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  transfer_sounds_.Stop();
  sound_channel_ = nullptr;
  desktop_wave_.Stop();
  if (tray_added_) Shell_NotifyIconW(NIM_DELETE, &tray_);
  tray_added_ = false;
  try { if (ble_publisher_) ble_publisher_.Stop(); } catch (...) {}
  ble_publisher_ = nullptr;
  proximity_channel_ = nullptr;
  file_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

bool FlutterWindow::ShowTrayNotice(const wchar_t* title, const std::wstring& body) {
  if (!tray_added_) return false;
  // A Shell balloon has no thumbnail or action buttons. Clicking it opens
  // Terax, where the verified receipt offers Abrir / Mostrar en carpeta.
  auto notice = tray_;
  notice.uFlags = NIF_INFO;
  notice.dwInfoFlags = NIIF_INFO | NIIF_NOSOUND;
  wcscpy_s(notice.szInfoTitle, title);
  size_t length = (std::min)(body.size(), std::size(notice.szInfo) - 1);
  // Do not leave half of a UTF-16 surrogate pair at the truncation boundary.
  if (length < body.size() && length > 0 &&
      body[length - 1] >= 0xd800 && body[length - 1] <= 0xdbff) --length;
  body.copy(notice.szInfo, length);
  notice.szInfo[length] = L'\0';
  return Shell_NotifyIconW(NIM_MODIFY, &notice) != FALSE;
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_CLOSE && tray_added_ && !exiting_) {
    ShowWindow(hwnd, SW_HIDE);
    if (!tray_hint_shown_) {
      tray_hint_shown_ = true;
      ShowTrayNotice(L"Terax", L"Terax sigue en la bandeja. Para cerrarlo del todo, usa Salir desde su icono.");
    }
    return 0;
  }
  if (message == WM_APP + 71) {
    ShowWindow(hwnd, SW_RESTORE); SetForegroundWindow(hwnd); return 0;
  }
  if (message == WM_APP + 70) {
    if (lparam == WM_LBUTTONDBLCLK || lparam == WM_LBUTTONUP ||
        lparam == NIN_BALLOONUSERCLICK) {
      ShowWindow(hwnd, SW_RESTORE); SetForegroundWindow(hwnd);
    } else if (lparam == WM_RBUTTONUP) {
      HMENU menu = CreatePopupMenu();
      AppendMenuW(menu, MF_STRING, 1, L"Abrir Terax");
      AppendMenuW(menu, MF_STRING, 2, L"Salir");
      POINT cursor; GetCursorPos(&cursor); SetForegroundWindow(hwnd);
      const auto selected = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON,
          cursor.x, cursor.y, 0, hwnd, nullptr);
      DestroyMenu(menu);
      if (selected == 1) { ShowWindow(hwnd, SW_RESTORE); SetForegroundWindow(hwnd); }
      if (selected == 2) { exiting_ = true; PostMessage(hwnd, WM_CLOSE, 0, 0); }
    }
    return 0;
  }
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
