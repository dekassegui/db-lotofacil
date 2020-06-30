#!/bin/bash

# Montagem da animação do tipo slideshow via FFmpeg usando as imagens – quadros
# – e sequência de apresentação – roteiro da animação – geradas pelo script
# contraparte – R/anima.R – conforme configuração arbitrária.

# checa pré-requisito – dependência única do subprojeto
if [[ ! $( which ffmpeg ) ]]; then
  echo -e "\nErro: Pacote \"ffmpeg\" não está disponível.\n"
  exit 0
fi

# retorna a duração da 'media' em segundos – floating point value
media_duration() {
  ffprobe -i "$*" -show_entries format=duration -v quiet -of csv="p=0"
}

# avaliação aritmética – floating point – da expressão explícita no argumento
evaluate() {
  echo "scale=5; $*" | bc -l
}

# prepara parâmetros para montagem da introdução com as declarações do
# primeiro quadro no roteiro original
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
pix=yuv420p       # adequado para iOS

common="-c:v $codec -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix"

# cria a introdução da animação com a capa e primeiro quadro da animação
ln -s $PWD/video/quadros/capa.png /tmp/img00.png
ln -s $PWD/video/$first /tmp/img01.png
A=$( evaluate "$duration/3" ) # duração em segundos de cada quadro da introdução
                              # sem FX – reduzida para evitar exposição excessiva
B=$( evaluate "2*$duration" ) # duração em segundos do FX tipo "crossfade"
X=$( evaluate "($A+$B)/$B" )  # número de quadros para cada imagem do FX
FPS=$( evaluate "1/$B" )      # output frame rate
intro=video/intro.mp4
filtros="zoompan=d=$X:s=svga:fps=$FPS, framerate=25:interp_start=0:interp_end=255:scene=100"
echo -e "\n$filtro\n"
ffmpeg -i /tmp/img%02d.png -vf "$filtros" $common -maxrate 5M -q:v 2 -y $intro
rm -f /tmp/img*.png

# cria animação tipo "slideshow" conforme roteiro
content=video/fun.mp4
ffmpeg -f concat -i $roteiro -vf 'scale=800:600' $common -y $content

# combina introdução e animação
comboFiles=video/combo.dat
[[ -e $comboFiles ]] && rm -f $comboFiles
echo -e "file '${intro##*/}'\nfile '${content##*/}'" > $comboFiles
combo=video/combo.mp4
ffmpeg -f concat -safe 0 -i $comboFiles -c copy -y $combo

# agrega áudio à combinação – obrigatoriamente é o último passo do algoritmo
# para que não sejam intrusivos entre os objetos previamente combinados

# agrega áudio de introdução
prefixo=video/audio/intro.wav
inputs="-i $combo -i $prefixo"
# agrega áudio de encerramento se possível
sufixo=video/audio/last.wav
tc=$( media_duration $combo )
ts=$( media_duration $sufixo )
if [[ $( evaluate "$tc >= ($ts+1)" ) == 1 ]]; then
  # prefixa com "0" evitando erro de argumento do "itsoffset" quando "evaluate"
  # retorna número entre 0 e 1 formatado sem o "0" que precede o separador
  # da parte fracionária – usualmente "."
  at=$( evaluate "x=$tc-$ts-1; if (x<1) print 0; print x" )
  inputs="$inputs -itsoffset $at -i $sufixo"
  kind=-filter_complex
  filters="[2:a]flanger=width=42, acontrast=50[FIM]; [1:a][FIM]amix=inputs=2, extrastereo=m=2"
  sync="-async 1"
else
  kind=-af
  filters="extrastereo=m=2"
fi
ffmpeg $inputs $kind "$filters" $sync -c:v copy -c:a aac -b:a 64k -y video/loto.mp4