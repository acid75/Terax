#include "../../windows/runner/ble_beacon.h"
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Foundation.h>
#include <iostream>
#include <thread>
#include <chrono>
int main() {
  winrt::init_apartment();
  try {
    auto adapter = winrt::Windows::Devices::Bluetooth::BluetoothAdapter::GetDefaultAsync().get();
    if (!adapter) { std::cout << "No default Bluetooth adapter\n"; return 2; }
    std::cout << "LE supported=" << adapter.IsLowEnergySupported()
              << " peripheral supported=" << adapter.IsPeripheralRoleSupported() << std::endl;
    auto radio = adapter.GetRadioAsync().get();
    std::cout << "Radio state=" << static_cast<int>(radio.State()) << " (On=1, Off=2, Disabled=3)" << std::endl;
    auto state = std::make_shared<terax_ble::PublisherState>();
    auto publisher = terax_ble::Create("00112233445566778899aabbccddeeff0123456789abcdef0123456789abcdef", state);
    auto data = publisher.Advertisement().ManufacturerData().GetAt(0);
    std::cout << "Manufacturer company=" << data.CompanyId() << " payload bytes=" << data.Data().Length() << std::endl;
    publisher.Start();
    std::string previous;
    for (int i=0; i<20; ++i) {
      auto status = terax_ble::Status(publisher, state);
      if (previous != status) { std::cout << "Publisher=" << status << std::endl; previous=status; }
      if (status == "ready" || status.find("aborted") == 0) break;
      std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
    publisher.Stop();
    std::cout << "Advertising stopped; no radio settings changed" << std::endl;
  } catch (const winrt::hresult_error& e) {
    std::cout << "HRESULT=" << e.code().value << " " << winrt::to_string(e.message()) << std::endl;
    return 1;
  }
}
