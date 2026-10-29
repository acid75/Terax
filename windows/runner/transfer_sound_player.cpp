#include "transfer_sound_player.h"
#include <windows.h>
#include <mmsystem.h>

bool TransferSoundPlayer::Play(const std::string& path) {
  if (path.empty() || path.size() > 32767 || path.find('\0') != std::string::npos) return false;
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.data(), static_cast<int>(path.size()), nullptr, 0);
  if (size <= 0) return false;
  std::wstring wide(size, L'\0');
  if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path.data(), static_cast<int>(path.size()), wide.data(), size) != size) return false;
  Stop();
  // Structured MCI arguments preserve literal Unicode paths, without command strings.
  MCI_OPEN_PARMSW open = {};
  open.lpstrDeviceType = L"mpegvideo";
  open.lpstrElementName = wide.c_str();
  if (mciSendCommandW(0, MCI_OPEN, MCI_OPEN_TYPE | MCI_OPEN_ELEMENT,
      reinterpret_cast<DWORD_PTR>(&open)) != 0) return false;
  device_ = open.wDeviceID;
  MCI_PLAY_PARMS play = {};
  if (mciSendCommandW(device_, MCI_PLAY, 0,
      reinterpret_cast<DWORD_PTR>(&play)) != 0) { Stop(); return false; }
  return true;
}
void TransferSoundPlayer::Stop() {
  if (!device_) return;
  mciSendCommandW(device_, MCI_STOP, MCI_WAIT, 0);
  mciSendCommandW(device_, MCI_CLOSE, MCI_WAIT, 0);
  device_ = 0;
}
