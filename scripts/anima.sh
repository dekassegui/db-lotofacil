#!/bin/bash

# Montagem da animação do tipo 'slideshow' via FFmpeg usando imagens – quadros
# – e sequência de apresentação – roteiro da animação – geradas pelo script
# contraparte – R/anima.R – conforme configuração arbitrária, agregando áudio –
# não intrusivo no desempenho da animação – associado a quadros correspondentes
# a concursos sem apostas ganhadoras do prêmio principal, além da introdução e
# do encerramento da animação.

# checa dependências do subprojeto
for command in ffmpeg ffprobe; do
  [[ $( which $command ) ]] && continue
  echo -e "\nErro: Pacote \"${command}\" não está disponível.\n"
  exit 0
done

# retorna a duração da mídia em segundos – floating point value
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
# preserva demais declarações para montagem da animação, evitando exibição
# redundante do primeiro quadro
roteiro=video/roteiro.dat
exec 4> $roteiro
while IFS= read -u 3 -r line; do echo $line >&4; done
exec 3<&-   4>&-

quality=34        # 0 (lossless) a 51 (sofrível) default 23
speed="medium"    # ultrafast superfast veryfast faster fast medium slow,‥
tune="animation"  # animation fastdecode film grain psnr stillimage zerolatency
codec=libx264     # video codec
pix=yuv420p       # adequado para iOS

common="-c:v $codec -profile:v baseline -preset $speed -tune $tune -crf $quality -pix_fmt $pix"

# cria a introdução da animação com a capa e primeiro quadro da animação
intro=video/intro.mp4
rm -f /tmp/img*.png
ln -s $PWD/video/quadros/capa.png /tmp/img00.png
ln -s $PWD/video/$first /tmp/img01.png
A=$( evaluate "$duration/3" ) # duração em segundos de cada quadro da introdução
                              # sem FX – reduzida para evitar exposição excessiva
B=$( evaluate "2*$duration" ) # duração em segundos do FX tipo "crossfade"
X=$( evaluate "($A+$B)/$B" )  # número de quadros para cada imagem do FX
FPS=$( evaluate "1/$B" )      # output frame rate
filters="zoompan=d=$X:s=svga:fps=$FPS, framerate=25:interp_start=0:interp_end=255:scene=100"

ffmpeg -i /tmp/img%02d.png -vf "$filters" $common -maxrate 5M -q:v 2 -y $intro

# cria animação tipo "slideshow" conforme roteiro
content=video/fun.mp4

ffmpeg -f concat -i $roteiro -vf 'scale=800:600' $common -y $content

# combina introdução e animação
combo=video/combo.mp4
comboFiles=video/combo.dat
[[ -e $comboFiles ]] && rm -f $comboFiles
echo -e "file '${intro##*/}'\nfile '${content##*/}'" > $comboFiles

ffmpeg -f concat -safe 0 -i $comboFiles -c copy -y $combo

# Agrega áudio à combinação recém gerada, associando SFX aos quadros da animação
# correspondentes a concursos sem apostas ganhadoras do prêmio principal – cujos
# números seriais são lidos de arquivo gerado pelo script contraparte R/anima.R –
# além de SFX na introdução e no encerramento quando possível.

final=video/loto.mp4            # arquivo da animação resultante

prefixo=video/audio/intro.wav   # áudio de introdução
sufixo=video/audio/last.wav     # áudio de encerramento
sfx=video/audio/click.wav       # áudio SFX de curta duração

ratio='4.0'  # razão entre volumes de saída e entrada

infiles=("-i $combo" "-i $prefixo")
filters="[1:a]volume=${ratio}[prefix];"
labels=("[prefix]")

# leitura dos números seriais dos concursos sem apostas ganhadoras
exec 3< video/acc.dat
read -u 3 -d "\n" -a acc
exec 3<&-
m=${#acc[*]}  # quantidade de concursos sem apostas ganhadoras

if (( m > 0 )); then

  infiles=("${infiles[@]}" "-i $sfx")
  filters="$filters [2:a]volume=${ratio}, asplit=$m "
  for (( i=0; i<m; i++ )); do filters="$filters[s$i]"; done
  filters="${filters};"

  # leitura do valor default da duração de cada quadro da animação
  exec 3< video/animacao.cfg
  while IFS= read -u 3 -r line; do [[ $line =~ ^default ]] && break; done
  exec 3<&-
  duration=${line#*=}               # duração de cada quadro da animação
  base=${first//[^0-9]/}            # número serial do concurso inicial
  start=$( media_duration $intro )  # duração da introdução

  # montagem dos parâmetros associando SFX aos concursos sem ganhadores
  for (( k=0; k<m; k++ )); do
    at=$(evaluate "x=($start+("${acc[k]}"-$base)*$duration)*1000; scale=0; x/1")
    filters="$filters [s$k]adelay=${at}|${at}[a$k];"
    labels=(${labels[*]} "[a$k]")
  done

fi

# montagem dos parâmetros do áudio de encerramento se a duração deste áudio mais
# um segundo é menor igual à duração do vídeo da combinação
tc=$( media_duration $combo )
ts=$( media_duration $sufixo )
if [[ $( evaluate "$tc >= ($ts+1)" ) == 1 ]]; then
  at=$(evaluate "x=($tc-$ts-1)*1000; scale=0; x/1")
  filters="$filters [${#infiles[@]}:a]volume=${ratio}, adelay=${at}|${at}[sufix];"
  labels=(${labels[*]} "[sufix]")
  infiles=("${infiles[@]}" "-i $sufixo")
fi

# agregação de áudio à animação via ffmpeg tal que o áudio é a combinação dos
# 'streams' mixados que é normalizada com estéreo ampliado
ffmpeg ${infiles[@]} -filter_complex "$filters ${labels[*]}amix=inputs=${#labels[*]}:dropout_transition=0, loudnorm, extrastereo=m=2" \
-c:v copy -c:a aac -b:a 96k -y $final
