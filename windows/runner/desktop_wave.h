#ifndef RUNNER_DESKTOP_WAVE_H_
#define RUNNER_DESKTOP_WAVE_H_

#include <windows.h>
#include <memory>
#include <string>

// Owns its render thread. Stop (also called by the destructor) must run before
// process teardown. Play takes an in-memory desktop snapshot BEFORE showing the
// overlay; desktop video underneath is not live during the 1.8 second effect.
// No capture is persisted. Calls to Play/Stop must be serialized by the caller.
class DesktopWave {
 public:
  DesktopWave();
  ~DesktopWave();
  DesktopWave(const DesktopWave&) = delete;
  DesktopWave& operator=(const DesktopWave&) = delete;
  bool Play(HWND owner, bool reducedMotion = false);
  bool active() const;
  std::string error() const;
  void Stop();

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

#endif  // RUNNER_DESKTOP_WAVE_H_
