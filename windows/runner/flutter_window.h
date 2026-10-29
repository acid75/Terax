#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Foundation.Collections.h>

#include <memory>
#include <string>

#include "win32_window.h"
#include "ble_beacon.h"
#include "desktop_wave.h"
#include "transfer_sound_player.h"
#include <shellapi.h>

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> file_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> proximity_channel_;
  winrt::Windows::Devices::Bluetooth::Advertisement::BluetoothLEAdvertisementPublisher ble_publisher_{nullptr};
  std::shared_ptr<terax_ble::PublisherState> ble_state_;
  DesktopWave desktop_wave_;
  TransferSoundPlayer transfer_sounds_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> sound_channel_;
  NOTIFYICONDATAW tray_{};
  bool tray_added_ = false;
  bool exiting_ = false;
  bool tray_hint_shown_ = false;
  bool ShowTrayNotice(const wchar_t* title, const std::wstring& body);
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
