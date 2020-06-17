#!/bin/bash

# Montagem da animação via ffmpeg.

# checa pré-requisito
if [[ ! $( which ffmpeg ) ]]; then

  echo -e "\nErro: Pacote \"ffmpeg\" não está disponível.\n"

else

  # obtêm o nome de todos os arquivos que comporão a animação como quadros
  readarray -t -d "" files < <(LC_ALL=C find ./video/quadros -maxdepth 1 -type f -regex ".*both.*\.png" -printf "%T@/%f\0" | sort -zn | cut -zd/ -f2)
  # checa a disponibilidade de arquivos
  if (( ${#files[*]} == 0 )); then
    echo -e "\n Erro: Não há imagens disponíveis.\n\n > Execute o script \"R/anima.R\" para gerar as imagens.\n"
    exit 0
  fi
  first=${files[0]:5:4}
  unset files

  audio=video/audio/start.wav
  codec=libx264
  quality=34
  speed="medium"
  tune="animation"
  pix=yuv420p

  # cria a introdução da animação com a capa e primeiro quadro da animação
  ln -s $PWD/video/quadros/capa.png /tmp/img00.png
  ln -s $PWD/video/quadros/both-$first.png /tmp/img01.png
  intro=video/intro.mp4
  A=.5   # duração em segundos de cada um dos frames da intro
  B=2    # duração em segundos do FX crossfade
  X=$( dc -e "5k $A $B + $B /p" )
  FPS=$( dc -e "5k 1 $B /p")
  ffmpeg -i /tmp/img%02d.png -i $audio -vf zoompan=d=$X:s=svga:fps=$FPS,framerate=25:interp_start=0:interp_end=255:scene=100 -c:v $codec -maxrate 5M -q:v 2 -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix -c:a aac -b:a 96k -y $intro
  rm -f /tmp/img*.png

  # cria a animação composta somente de quadros tal que "roteiro.txt" é montado
  # pelo script R/anima.R
  content=video/fun.mp4
  ffmpeg -f concat -i video/roteiro.txt -vf 'scale=800:600' -c:v $codec -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix -y $content

  # combina as animações
  merge=video/merge.dat
  [[ -e $merge ]] || echo -e "file ${intro##*/}\nfile ${content##*/}" > $merge
  ffmpeg -f concat -safe 0 -i $merge -c copy -y video/loto.mp4

fi
