#!/bin/bash

# Montagem da animação via ffmpeg

# checa pré-requisito
if [[ ! $( which ffmpeg ) ]]; then

  echo -e "\nErro: Pacote \"ffmpeg\" não está disponível.\n"

else

  # prepara parâmetros para montagem da introdução com as declarações do
  # primeiro quadro no roteiro original – montado pelo script "R/anima.R"
  exec 3< video/roteiro.txt
  while IFS= read -u 3 -r line; do [[ $line =~ ^file ]] && break; done
  first=$( echo ${line#* } | tr -d "'\"" )
  while IFS= read -u 3 -r line; do [[ $line =~ ^duration ]] && break; done
  duration=${line#* }
  # armazena demais declarações para montagem da animação, evitando exibição
  # redundante do primeiro quadro
  roteiro=video/roteiro.dat
  exec 4> $roteiro
  while IFS= read -u 3 -r line; do echo $line >&4; done
  exec 3<&-   4>&-

  quality=34        # 0 (lossless) a 51 (sofrível) default 23
  speed="medium"    # ultrafast, superfast, veryfast, faster, fast, medium,
                    # slow, slower, veryslow
  tune="animation"  # animation fastdecode film grain psnr stillimage
                    # zerolatency
  codec=libx264
  pix=yuv420p       # adequado até para iOS

  # cria a introdução da animação com a capa e primeiro quadro da animação
  ln -s $PWD/video/quadros/capa.png /tmp/img00.png
  ln -s $PWD/video/$first /tmp/img01.png
  A=$duration           # duração em segundos de cada um dos quadros da intro
  B=$(( 2*duration ))   # duração em segundos do FX crossfade
  X=$( dc -e "5k $A $B + $B /p" )
  FPS=$( dc -e "5k 1 $B /p" )
  intro=video/intro.mp4
  ffmpeg -i /tmp/img%02d.png -vf "zoompan=d=$X:s=svga:fps=$FPS, framerate=25:interp_start=0:interp_end=255:scene=100" -c:v $codec -maxrate 5M -q:v 2 -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix -y $intro
  rm -f /tmp/img*.png

  # cria animação tipo slideshow conforme roteiro
  content=video/fun.mp4
  ffmpeg -f concat -i $roteiro -vf 'scale=800:600' -c:v $codec -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix -y $content

  # combina introdução e animação
  merge=video/merge.dat
  [[ -e $merge ]] || echo -e "file ${intro##*/}\nfile ${content##*/}" > $merge
  combo=video/combo.mp4
  ffmpeg -f concat -safe 0 -i $merge -c copy -y $combo

  # agrega áudio à combinação – último passo do algoritmo, garantindo áudio
  # não intrusivo caso seja mais longo que a introdução
  audio=video/audio/intro.wav
  ffmpeg -i $combo -i $audio -c:v copy -c:a aac -b:a 64k -y video/loto.mp4

fi
