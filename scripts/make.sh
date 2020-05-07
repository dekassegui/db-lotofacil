#!/bin/bash

# formata indiferentemente ao separador de campos, data no formato
# yyyy.mm.dd ou dd.mm.yyyy como data no formato yyyy-mm-dd
full_date() {
  # padroniza os separadores de campos
  local d=${1//[^0-9]/-}
  # se a data é dd-mm-yyyy então modifica para yyyy-mm-dd
  [[ ${d:2:1} == '-' ]] && echo ${d:6:4}-${d:3:2}-${d:0:2} || echo $d
}

# formata indiferentemente ao separador de campos, data no formato
# yyyy.mm.dd ou dd.mm.yyyy como data no formato "data por extenso"
long_date() {
  date -d $(full_date $1) '+%A, %d de %B de %Y'
}

# Computa a data presumida do concurso da Lotofácil anterior e mais recente que
# a data ISO-8601 fornecida ou a data corrente do sistema em caso contrário.
loto_date() {
  (( $# )) && dia=$* || dia=$(date +'%F %H:%M:%S')
  read u F ndays <<< $(date -d "$dia" +'%u %F 0')
  # testa se dia da semana da data referência é terça, quinta, sábado ou domingo
  # representados por 212 == 1<<2 | 1<<4 | 1<<6 | 1<<7
  if (( 212 & 1<<$u )); then
    ndays=$(( 1 + $u % 2 ))
  # testa se horário da data referência, cujo dia da semana é segunda, quarta
  # ou sexta, é anterior a 20:00 <-- horário usual dos sorteios
  elif (( $(date -d "$dia" +%s) < $(date -d "$F 20:00" +%s) )); then
    ndays=$(( $u>1 ? 2 : 3 ))
  fi
  date -d "$F -$ndays days" +%F
}

echo -e '\nData presumida do sorteio mais recente: '$(long_date $(loto_date))'.'

declare -r dbFile='loto.sqlite'
declare -r xml='loto.xml'

# extrai a data da última modificação de arquivo em segundos da era unix
timestamp() {
  stat -c %Y "$1"
}

xpath() {
  xmllint --xpath "$1" $xml
}

# expressão XPath p/obter a quantidade de registros de concursos no xml
declare -r count_n_xml='count(//table/tr[count(td)=33])'

sqlite() {
  if [[ $1 == '-separator' ]]; then
    local sep="$2"
    shift 2
    sqlite3 -separator "$sep" $dbFile "$*"
  else
    sqlite3 $dbFile "$*"
  fi
}

# sql p/obter a quantidade de registros na tabela 'concursos'
declare -r count_n_db='SELECT COUNT(concurso) FROM concursos'

# link remoto para acessar zipfile atualizado a cada concurso
declare -r url='http://www1.caixa.gov.br/loterias/_arquivos/loterias/D_lotfac.zip'

# extrai o nome do zipfile
declare -r zipfile=${url##*/}

# se o zipfile existir localmente preserva seu timestamp
[[ -e $zipfile ]] && declare -i tm=$(timestamp $zipfile)

# tenta baixar zipfile remoto possivelmente atualizado
wget -o wget.log --no-cache --timestamping $url

# termina a execução do script se o zipfile não está disponível
if [[ ! -e $zipfile ]]; then
  printf '\nErro: Arquivo "%s" não está disponível.\n\n' $zipfile
  exit 1
fi

printf '\nInformação: "%s" ' $zipfile
if [[ $tm ]]; then
  # termina execução se zipfile não foi atualizado
  if (( $tm >= $(timestamp $zipfile) )); then
    printf 'não foi atualizado.\n\n'
    exit 1
  fi
  printf 'foi atualizado.\n'
else
  printf 'está disponível.\n'
fi

# extrai conteúdo do zipfile para o diretório temporário
unzip --qu -o $zipfile -d '/tmp'

# obtêm o filename do html recém extraído
htm="/tmp/"$(unzip -l $zipfile | sed -nr '/^.*htm$/ s/^.* (\w+\.htm)$/\1/p')

# converte o html para xml com encoding utf8
enc=$(file --mime-encoding $htm)
iconv -f ${enc#* } -t 'utf8' $htm | sed -r -f 'scripts/xml.sed' > $xml

if [[ -e $dbFile ]] && (( $(xpath $count_n_xml) == $(sqlite $count_n_db) ))
then
  printf '\nInformação: Quantidade de registros no DB e no XML coincidem.\n\n'
  exit 1
fi

# monta o DB com dados extraídos do XML

buf='/tmp/concursos.dat'
xsltproc -o $buf --stringparam SEPARATOR '|' 'scripts/concursos.xsl' $xml

sqlite3 loto.sqlite <<EOT
.read sql/monta.sql
.import $buf concursos
EOT

buf='/tmp/ganhadores.dat'
xsltproc -o $buf --stringparam SEPARATOR '|' 'scripts/ganhadores.xsl' $xml

sqlite3 loto.sqlite ".import $buf ganhadores"
