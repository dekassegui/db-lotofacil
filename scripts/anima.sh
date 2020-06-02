#!/bin/bash

# arquivo de áudio prefixo da animação
audio=video/audio/intro.wav
# quality ranges from 0 to 51 :: 0 is lossless, 23 is the default, 51 is the
# worst quality possible and a sane range is 17–28
quality=34
# ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
speed="medium"
# film animation grain stillimage fastdecode zerolatency psnr
tune="animation"
# cria a animação composta de quadros e áudio
ffmpeg -f concat -i video/roteiro.txt -i $audio -vf 'scale=800:600' -c:v libx264 -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt yuv420p -c:a aac -b:a 96k -y video/fun.mp4
