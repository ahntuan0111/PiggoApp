# coding=utf-8
from gtts import gTTS
import os

text = "Sáng nay đi ăn phở hết năm chục ngàn."
tts = gTTS(text, lang='vi')
tts.save("test_voice.mp3")
