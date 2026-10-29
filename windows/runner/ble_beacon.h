#pragma once
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <memory>
#include <mutex>
#include <string>
#include <stdexcept>

namespace terax_ble {
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
struct PublisherState {
  std::mutex mutex;
  std::string error;
};
inline BluetoothLEAdvertisementPublisher Create(const std::string& fingerprint,
                                                 std::shared_ptr<PublisherState> state) {
  if (fingerprint.size() != 64 || fingerprint.find_first_not_of("0123456789abcdefABCDEF") != std::string::npos)
    throw std::invalid_argument("Fingerprint must contain 64 hexadecimal characters");
  winrt::Windows::Storage::Streams::DataWriter writer;
  writer.WriteByte('T'); writer.WriteByte('R'); writer.WriteByte('X'); writer.WriteByte(2);
  for (size_t i = 0; i < 32; i += 2)
    writer.WriteByte(static_cast<uint8_t>(std::stoul(fingerprint.substr(i, 2), nullptr, 16)));
  BluetoothLEAdvertisementPublisher publisher;
  BluetoothLEManufacturerData data;
  // 0xffff is reserved for experimental/internal use, not a claimed company ID.
  data.CompanyId(0xffff);
  data.Data(writer.DetachBuffer());
  publisher.Advertisement().ManufacturerData().Append(data);
  publisher.StatusChanged([state](const auto&, const BluetoothLEAdvertisementPublisherStatusChangedEventArgs& args) {
    std::lock_guard<std::mutex> lock(state->mutex);
    if (args.Status() == BluetoothLEAdvertisementPublisherStatus::Aborted)
      state->error = "aborted (BluetoothError=" + std::to_string(static_cast<int>(args.Error())) + ")";
    else if (args.Status() == BluetoothLEAdvertisementPublisherStatus::Started ||
             args.Status() == BluetoothLEAdvertisementPublisherStatus::Waiting)
      state->error.clear();
  });
  return publisher;
}
inline std::string Status(const BluetoothLEAdvertisementPublisher& publisher,
                          const std::shared_ptr<PublisherState>& state) {
  if (!publisher) return "unavailable";
  std::lock_guard<std::mutex> lock(state->mutex);
  if (!state->error.empty()) return state->error;
  switch (publisher.Status()) {
    case BluetoothLEAdvertisementPublisherStatus::Started: return "ready";
    case BluetoothLEAdvertisementPublisherStatus::Waiting: return "waiting";
    case BluetoothLEAdvertisementPublisherStatus::Created: return "starting";
    case BluetoothLEAdvertisementPublisherStatus::Stopped: return "stopped";
    case BluetoothLEAdvertisementPublisherStatus::Stopping: return "stopping";
    case BluetoothLEAdvertisementPublisherStatus::Aborted: return state->error.empty() ? "aborted (awaiting BluetoothError)" : state->error;
    default: return "unavailable";
  }
}
}
