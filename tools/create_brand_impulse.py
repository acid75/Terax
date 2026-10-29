"""Alternative non-musical Terax signatures, authored without external samples."""
from pathlib import Path
import numpy as np,wave
ROOT=Path(__file__).resolve().parents[1];RATE=48000

def noise_band(rng,n,center,width):
 f=np.fft.rfftfreq(n,1/RATE)
 spectrum=np.exp(-.5*((f-center)/width)**2)*(1-np.exp(-(f/180)**4));spectrum[0]=0
 x=np.fft.irfft(np.fft.rfft(rng.standard_normal(n))*spectrum,n=n)
 return x/(np.std(x)+1e-9)

def render(arrival,style):
 duration=(.38 if arrival else .26) if style=='air' else (.29 if arrival else .20)
 t=np.arange(round(duration*RATE))/RATE;p=t/duration
 rng=np.random.default_rng(74012+(style=='deep')*70+arrival)
 low=noise_band(rng,len(t),650 if style=='air' else 490,260)
 high=noise_band(rng,len(t),1850 if style=='air' else 1100,650 if style=='air' else 420)
 if not arrival:
  # A broad, smooth release with a little acceleration; no pitched note sequence.
  lift=np.sin(np.pi*p)**1.8
  blend=p**.7
  x=(low*(1-blend)*.68+high*blend*.43)*lift
  body=np.sin(2*np.pi*(480*t+100*t*t/duration))*np.exp(-((p-.40)/.20)**2)
  x+=body*(.11 if style=='air' else .38)
 else:
  # Rounded contact, then soft air settling: not a bell or a cartoon chirp.
  onset=(1-np.exp(-t/.008))**2
  fall=np.exp(-t/(.055 if style=='air' else .035))
  contact=low*.50+high*.22
  body=np.sin(2*np.pi*(560*t-90*t*t/duration))
  x=(contact+body*(.18 if style=='air' else .75))*onset*fall
  x+=high*.065*np.exp(-((p-.40)/.14)**2)
  x+=low*.04*np.exp(-((p-.59)/.13)**2)
  if style=='air':
   # The selected direction is enveloping air, with no hard contact or bell.
   settle=np.sin(np.pi*p)**1.65*np.exp(-p*.8)
   x=(low*.36+high*.30*(1-p))*settle
   x+=np.sin(2*np.pi*(510*t-50*t*t/duration))*.045*settle
 # Roll off the edges and normalize with headroom. No brick-wall limiting.
 edge=np.clip(t/.006,0,1)*np.clip((duration-t)/.035,0,1)
 x*=edge**2*(3-2*edge);x-=np.mean(x);x*=edge
 x*=.72/np.max(np.abs(x));x[0]=x[-1]=0
 return np.rint(x*32767).astype('<i2')
def save(path,data):
 with wave.open(str(path),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE);f.writeframes(data.tobytes())
if __name__=='__main__':
 folder=ROOT/'tmp/audio-masters';folder.mkdir(exist_ok=True)
 for style in ['air','deep']:
  out,inc=render(False,style),render(True,style)
  for name,data in [('departure',out),('arrival',inc),('demo',np.concatenate([out,inc]))]:
   save(folder/f'{style}-{name}.wav',data)
   print(style,name,len(data)/RATE,'RMS',round(20*np.log10(np.sqrt(np.mean((data.astype(float)/32768)**2))),1))
