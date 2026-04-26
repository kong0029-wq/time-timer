import wave
import struct
import math

def generate_tone(filename, freq, duration, volume=0.5, rate=44100):
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(rate)
        
        num_frames = int(duration * rate)
        
        for i in range(num_frames):
            # Apply a simple envelope (decay)
            env = math.exp(-3.0 * i / num_frames)
            value = int(volume * env * 32767.0 * math.sin(2.0 * math.pi * freq * i / rate))
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

# Chime sound: A mix of frequencies
def generate_chime(filename, duration=1.5, rate=44100):
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(rate)
        
        num_frames = int(duration * rate)
        
        for i in range(num_frames):
            env = math.exp(-4.0 * i / num_frames)
            v1 = math.sin(2.0 * math.pi * 523.25 * i / rate) # C5
            v2 = math.sin(2.0 * math.pi * 659.25 * i / rate) # E5
            v3 = math.sin(2.0 * math.pi * 783.99 * i / rate) # G5
            
            value = int(0.3 * env * 32767.0 * (v1 + v2 + v3) / 3)
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

generate_tone('assets/beep.wav', 880.0, 1.0)
generate_chime('assets/chime.wav', 2.0)
print("Sounds generated.")
