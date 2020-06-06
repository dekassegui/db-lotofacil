#!/bin/bash

# Montagem do arquivo do roteiro da animação melhorado com SFX "blend" para
# transição do primeiro para o segundo quadro da animação.

# checa pré-requisito
if [[ ! $( which convert ) ]]; then
  echo -e "\nErro: pacote \"imagemagick\" não está disponível\n"
  exit 0
fi

echo -e "\nProcessando quadros da animação, aguarde.\n"

rm -f video/quadros/kapa*   # limpeza do buffer

exec 3< video/roteiro.txt 4> /tmp/enhanced.dat    # open files

# retorna linha do roteiro pertinente ao padrão regexp fornecido
READ(){
  local LINE
  while IFS= read -u 3 -r LINE; do [[ $LINE =~ $1 ]] && break; done
  echo $LINE
}

# retorna o path do arquivo na declaração fornecida
GET(){ echo ${1#* } | tr -d "'\""; }

# leitura da primeira declaração de arquivo – capa da transição
line=$( READ "^file" )
echo -e $line"\n"$( READ '^duration' ) >&4
capa=$( GET "$line" )

# leitura da segunda declaração de arquivo – contracapa da transição
line=$( READ "^file" )
[[ $line =~ ^file\ .*kapa- ]] && line=$( READ "^file\ .*both-" )
contra_capa=$( GET "$line" )

# loop de criação dos quadros da transição
for (( opacity=3; opacity<100; opacity=opacity+3 )); do
  printf -v fname "quadros/kapa-%02d.png" $opacity
  # cria arquivo de quadro de transição
  convert video/$capa video/$contra_capa \
    -adaptive-blur 0x1 -gravity center -alpha on -compose blend \
    -define compose:args=$opacity -composite video/$fname
  # insere info de quadro de transição no roteiro
  echo -e "file '$fname'\nduration 0.125" >&4
done

# completa o roteiro com a declaração pendente e restantes
while [[ -n $line ]]; do echo $line >&4; IFS= read -u 3 -r line; done

exec 3<&- 4>&-    # close files

# substituição do roteiro original pelo melhorado
mv /tmp/enhanced.dat video/roteiro.txt
