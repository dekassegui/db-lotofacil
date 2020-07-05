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
speed="medium"    # ultrafast, superfast, veryfast, faster, fast, medium,
                  # slow, slower, veryslow
tune="animation"  # animation fastdecode film grain psnr stillimage
                  # zerolatency
codec=libx264
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

# agrega áudio à combinação recém gerada, associando SFX aos quadros da animação
# correspondentes a concursos sem apostas ganhadoras do prêmio principal – cujos
# números seriais são lidos de arquivo gerado pelo script contraparte R/anima.R –

final=video/loto.mp4            # arquivo da animação resultante

prefixo=video/audio/intro.wav   # áudio de introdução
sufixo=video/audio/last.wav     # áudio de encerramento
sfx=video/audio/click.wav       # áudio SFX de curta duração

ratio='4.0'  # razão entre volumes de saída e entrada

inputs=( -i $combo -i $prefixo )
filters=( "[1:a]volume=${ratio}[a1];" )
labels=( "[a1]" )
weights=( 1 )

# leitura dos números seriais dos concursos cumulativos
exec 3< video/acc.dat
read -u 3 -d "\n" -a acc
exec 3<&-
m=${#acc[*]}  # quantidade de concursos cumulativos

if (( m > 0 )); then

  # leitura do valor default da duração de cada quadro da animação
  exec 3< video/animacao.cfg
  while IFS= read -u 3 -r line; do [[ $line =~ ^default ]] && break; done
  exec 3<&-
  duration=${line#*=}   # duração de cada quadro da animação

  base=${first//[^0-9]/}            # número serial do concurso inicial
  start=$( media_duration $intro )  # duração da introdução

  # prepara parâmetros associando SFX aos concursos cumulativos
  for (( k=0, j=2; k<m; k++, j++ )); do
    at=$( evaluate "$start+("${acc[k]}"-$base)*$duration" )
    inputs=( ${inputs[*]} -itsoffset $at -i $sfx )
    filters=( ${filters[*]} "[$j:a]volume=${ratio}[a$j];" )
    labels=( ${labels[*]} "[a$j]" )
    weights=( ${weights[*]} 2 )
  done

fi

# agrega o áudio de encerramento se possível
tc=$( media_duration $combo )
ts=$( media_duration $sufixo )
if [[ $( evaluate "$tc >= ($ts+1)" ) == 1 ]]; then
  # prefixa com "0" evitando erro de argumento do "itsoffset" quando "evaluate"
  # retorna número entre 0 e 1 formatado sem o "0" que precede o separador
  # da parte fracionária – usualmente "."
  at=$( evaluate "x=$tc-$ts-1; if (x<1) print 0; print x" )
  inputs=( ${inputs[*]} -itsoffset $at -i $sufixo )
  m=$(( 2 + $m ))
  filters=( ${filters[*]} "[$m:a]volume=${ratio}[a$m];" )
  labels=( ${labels[*]} "[a$m]" )
  weights=( ${weights[*]} 1 )
fi

# combinação dos filtros individuais + normalização + estéreo ampliado
filters="${filters[*]} ${labels[*]}amix=inputs=${#labels[*]}:weights=${weights[*]}:dropout_transition=0, loudnorm, extrastereo=m=2"

ffmpeg ${inputs[*]} -filter_complex "$filters" -async 1 -c:v copy -c:a aac -b:a 64k -y $final
