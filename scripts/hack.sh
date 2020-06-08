#!/bin/bash

# Montagem do arquivo do roteiro da animação melhorado com SFX "blend" para
# transição suave do primeiro para o segundo quadro da animação.

# checa pré-requisito
if [[ ! $( which convert ) ]]; then

  echo -e "\nNota: Pacote \"imagemagick\" não está disponível.\n"

else

  printf "\n> Criando quadros da transição"

  rm -f video/quadros/kapa*   # exclui arquivos de transição antigos

  exec 3< video/roteiro.txt 4> /tmp/enhanced.dat  # open files

  # retorna a próxima linha do roteiro pertinente ao padrão regexp fornecido
  READ(){
    local LINE
    while IFS= read -u 3 -r LINE; do [[ $LINE =~ $1 ]] && break; done
    echo $LINE
  }

  # leitura e impressão da primeira declaração de arquivo – capa da transição –
  # e respectiva duração – tempo de exposição do quadro –
  line=$( READ "^file" )
  echo -e $line"\n"$( READ '^duration' ) >&4
  capa=$( echo ${line#* } | tr -d "'\"" )

  # leitura da segunda declaração de arquivo – contracapa da transição –
  # ignorando declarações de quadros de transição se roteiro já processado
  line=$( READ "^file\ .*both-" )
  contra_capa=$( echo ${line#* } | tr -d "'\"" )

  # loop de criação dos quadros da transição
  for (( opacity=3; opacity<100; opacity=opacity+3 )); do
    printf "."
    printf -v fname "quadros/kapa-%02d.png" $opacity
    # cria arquivo de quadro de transição
    convert video/$capa video/$contra_capa -gravity center -antialias \
      -alpha on -compose blend -define compose:args=$opacity \
      -composite video/$fname
    # insere info de quadro de transição no roteiro
    echo -e "file '$fname'\nduration 0.125" >&4
  done

  # completa o roteiro com a segunda declaração – pendente – e restantes
  while [[ -n $line ]]; do echo $line >&4; IFS= read -u 3 -r line; done

  exec 3<&- 4>&-  # close files

  # substituição do roteiro pré-existente pelo melhorado
  mv /tmp/enhanced.dat video/roteiro.txt

  printf "finalizado.\n\n"

fi
