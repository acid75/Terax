"""Author the original Terax Lift sonic signature. Requires numpy; no runtime DSP.
A soft air lift and rounded resonant body join across D6; G resolves the arrival.
PCM mono is intentional: the signature must survive a small phone speaker.
"""
from pathlib import Path
import numpy as np
import wave,json
RATE=48000
ROOT=Path(__file__).resolve().parents[1]
def render(incoming):
    seconds=.62 if incoming else .38
    t=np.arange(round(seconds*RATE))/RATE
    rng=np.random.default_rng(20261028+(1 if incoming else 0))
    white=rng.standard_normal(len(t));f=np.fft.rfftfreq(len(t),1/RATE)
    band=(f/1500)**1.2*np.exp(-(f/3100)**2);band[0]=0
    air=np.fft.irfft(np.fft.rfft(white)*band,n=len(t));air/=max(np.std(air),1e-9)
    lift=np.exp(-((t-(.11 if incoming else .16))/.065)**2)
    sound=air*lift*(.012 if incoming else .028)
    notes=([(0.012,1174.659,.78,.12),(.105,1567.982,1.0,.145),(.12,783.991,.18,.13)] if incoming else [(0.018,783.991,1.0,.08),(.115,1174.659,.78,.105)])
    for offset,hz,amp,decay in notes:
        age=np.maximum(t-offset,0);active=(t>=offset)
        attack=np.sin(np.minimum(age/.009,1)*np.pi/2)**2
        env=attack*np.exp(-age/decay)*active
        phase=2*np.pi*hz*age
        # A rounded resonator with restrained, rapidly fading upper modes.
        body=np.sin(phase+.26*np.exp(-age/.024)*np.sin(phase*2))
        body+=.12*np.sin(phase*2.003)*np.exp(-age/.07)
        body+=.045*np.sin(phase*3.97)*np.exp(-age/.027)
        sound+=amp*env*body
    dry=sound.copy()
    for delay,gain in [(.027,.10),(.043,.055),(.071,-.027),(.103,.018)]:
        shift=round(delay*RATE);sound[shift:]+=dry[:-shift]*gain
    end=np.clip((seconds-t)/.055,0,1);start=np.clip(t/.004,0,1)
    sound*=end**2*(3-2*end)*start**2*(3-2*start)
    sound-=np.mean(sound);sound*=end*start
    sound*=.62/np.max(np.abs(sound));sound[0]=sound[-1]=0
    return np.rint(sound*32767).astype('<i2')
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(data.tobytes())
if __name__=='__main__':
    departure,arrival=render(False),render(True)
    for name,data in [('departure',departure),('arrival',arrival)]:
        path=ROOT/'tmp/audio-masters'/f'terax-{name}-v3.wav';save(path,data)
        print(path.name, 'seconds',len(data)/RATE,'peak',max(abs(data.astype(float)))/32768,'rms',np.sqrt(np.mean((data.astype(float)/32768)**2)))
    save(ROOT/'tmp/terax-lift-signature-v3.wav',np.concatenate([departure,arrival]))
