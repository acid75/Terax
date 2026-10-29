#ifndef TERAX_TRANSFER_SOUND_PLAYER_H_
#define TERAX_TRANSFER_SOUND_PLAYER_H_
#include <string>
class TransferSoundPlayer {
 public:
  bool Play(const std::string& path);
  void Stop();
  ~TransferSoundPlayer() { Stop(); }
 private:
  unsigned int device_ = 0;
};
#endif
