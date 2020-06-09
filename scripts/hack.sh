#!/bin/bash

# Remontagem do arquivo do roteiro da animação melhorado com SFX "blend" para
# transição suave do primeiro para o segundo quadro da animação.

# definições antecipadas devido ao escopo
shopt -s expand_aliases               # enable alias expansion
alias NOP=":"                         # bash null command that does nothing
alias ReadPar="read -r -u 3 -a Par"   # input array Par from file with fd=3

# checa pré-requisito
if [[ ! $( which convert ) ]]; then

  echo -e "\nNota: Pacote \"imagemagick\" não está disponível.\n"

else

  Print () { echo -e "${@}" >&4; }    # output to file with fd=4

  printf "\n> Criando quadros da transição"

  rm -f video/quadros/kapa*   # exclui arquivos de transição antigos

  exec  3< video/roteiro.txt    4> /tmp/enhanced.dat    # open files

  declare -a Par  # array único das declarações ( tipo valor )

  # leitura e impressão da primeira declaração de arquivo – capa da transição –
  # e respectiva duração – tempo de exposição do quadro –
  while ReadPar && [[ ${Par[0]} != 'file' ]]; do NOP; done
  capa=${Par[1]//[\'\"]/}
  while ReadPar && [[ ${Par[0]} != 'duration' ]]; do NOP; done
  Print "file '$capa'\n${Par[@]}"

  # leitura da segunda declaração de arquivo – contracapa da transição –
  # ignorando declarações de quadros de transição se roteiro já processado
  while ReadPar && [[ ! ${Par[1]} =~ .+both- ]]; do NOP; done
  contra_capa=${Par[1]//[\'\"]/}

  # loop de criação dos quadros da transição
  for (( opacity=3; opacity<100; opacity=opacity+3 )); do
    printf '.'
    printf -v fname "quadros/kapa-%02d.png" $opacity
    # cria arquivo de quadro de transição
    convert video/$capa video/$contra_capa -gravity center -antialias \
      -alpha on -compose blend -define compose:args=$opacity \
      -composite video/$fname
    # insere info de quadro de transição no roteiro
    Print "file '$fname'\nduration 0.125"
  done

  # output da segunda declaração pendente e das declarações restantes
  while Print ${Par[@]} && ReadPar; do NOP; done

  exec  3<&-  4>&-  # close files

  # substituição do roteiro pré-existente pelo melhorado
  mv /tmp/enhanced.dat video/roteiro.txt

  printf "finalizado.\n\n"

fi
