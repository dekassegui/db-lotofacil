#!/bin/bash

# checa pré-requisito
if [[ ! $( which convert ) ]]; then
  echo -e "\nErro: pacote \"imagemagick\" não está disponível\n"
  exit 0
fi
# restaura roteiro original se necessário
if (( $( grep -Pc "^file\s.*\bkapa-\d\d\.png" video/roteiro.txt ) > 0 )); then
  # exclui as linhas que coincidem com o padrão regexp que identifica quadro
  # de transição e respectivas linhas consecutivas das durações
  sed -ru "/kapa/,+1 d" video/roteiro.txt > /tmp/original.txt
  # move o arquivo resultante que é o roteiro original
  mv /tmp/original.txt video/roteiro.txt
fi
# obtêm o nome de todos os arquivos de quadros da animação
readarray -t -d "" files < <(LC_ALL=C find ./video/quadros -maxdepth 1 \
  -type f -regex ".*both.*\.png" -printf "%T@/%f\0" | sort -zn | cut -zd/ -f2)
# preserva o nome do primeiro arquivo
first=${files[0]}
unset files
# prepara arquivo do roteiro melhorado
exec 3<> /tmp/enhanced.dat  # open to write
(( n=0 ))
while IFS= read -r line; do
  echo $line >&3
  (( ++n != 2 )) && continue
  # loop de criação dos quadros de transição
  for (( m=1; m<20; m++ )); do
    printf -v fname "quadros/kapa-%02d.png" $m
    # cria arquivo de quadro de transição
    convert video/quadros/capa.png video/quadros/$first -alpha on \
      -compose blend -define compose:args=$(( m*5 )) -gravity center \
      -composite video/$fname
    # insere info de quadro de transição no roteiro
    echo -e "file '$fname'\nduration 0.2" >&3
  done
done < video/roteiro.txt
exec 3>&-   # close
# substituição do roteiro original pelo melhorado
mv /tmp/enhanced.dat video/roteiro.txt
