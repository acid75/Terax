#include "desktop_wave.h"
#include <chrono>
#include <cstring>
#include <iostream>
#include <thread>

int main(int argc, char** argv) {
  // This probe never writes captured pixels. --play explicitly runs the real
  // desktop effect; default mode tests idle lifecycle without capturing.
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
  DesktopWave wave;
  if (argc < 2 || (std::strcmp(argv[1],"--play") != 0 &&
                   std::strcmp(argv[1],"--reduced-motion") != 0)) {
    if (wave.active() || !wave.error().empty()) return 1;
    wave.Stop(); wave.Stop();
    std::cout << "Idle lifecycle passed. Use --play or --reduced-motion for actual desktop effect.\n";
    return 0;
  }
  HWND foreground = GetForegroundWindow();
  POINT pointer = {};
  GetCursorPos(&pointer);
  const auto start = std::chrono::steady_clock::now();
  if (!wave.Play(foreground,std::strcmp(argv[1],"--reduced-motion")==0)) {
    std::cerr << "Setup failed: " << wave.error() << '\n'; return 2;
  }
  std::cout << "GPU/composition setup succeeded; active=" << wave.active() << '\n';
  while (wave.active()) {
    if (std::chrono::steady_clock::now()-start > std::chrono::seconds(8)) {
      wave.Stop(); std::cerr << "Timed out\n"; return 3;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(20));
  }
  wave.Stop();
  POINT after = {};
  GetCursorPos(&after);
  std::cout << "Duration milliseconds=" << std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now()-start).count()
      << "; foreground preserved=" << (foreground==GetForegroundWindow())
      << "; pointer preserved=" << (pointer.x==after.x && pointer.y==after.y) << '\n';
  if (!wave.error().empty()) { std::cerr << wave.error() << '\n'; return 4; }
  return 0;
}
