#!/bin/bash
#
# Script para atualizar e (re)criar, se necessário, o db da Lotofácil com dados
# baixados do website da Caixa Econômica Federal Loterias, conforme mudança na
# oferta pública de dados da série temporal dos concursos em 07 de maio de 2021.

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

# computa a data presumida do concurso da Lotofácil anterior e mais recente que
# a data ISO-8601 fornecida ou a data corrente do sistema em caso contrário
loto_date() {
  # prepara a data alvo com data arbitrária ou data corrente
  (( $# )) && dia=$(date -d "$*" +'%F %H:%M:%S %z') || dia=$(date +'%F %H:%M:%S %z')
  read u F ndays <<< $(date -d "$dia" +'%u %F 0')
  # testa se data alvo é segunda e se horário da data alvo é anterior a 20:00
  # que é o horário usual dos sorteios
  if (( $u == 1 && $(date -d "$dia" +%s) < $(date -d "$F 20:00" +%s) )); then
    ndays=2
  # testa se data alvo é domingo ou se horário da data alvo é anterior a 20:00
  elif (( $u == 7 || $(date -d "$dia" +%s) < $(date -d "$F 20:00" +%s) )); then
    ndays=1
  fi
  date -d "$F -$ndays days" +%F
}

echo -e '\nData presumida do sorteio mais recente: '$(long_date $(loto_date))'.'

declare -r html=resultados.html       # arquivo da série temporal de concursos
                                      # baixado a cada execução e preservado até
                                      # a seguinte como backup
declare -r dbname=loto.sqlite         # arquivo do db SQLite, opcionalmente
                                      # (re)criado, preenchido a cada execução
declare -r concursos=concursos.dat    # arquivo plain/text dos dados de
                                      # concursos para preenchimento do db
declare -r ganhadores=ganhadores.dat  # arquivo plain/text dos dados de
                                      # acertadores para preenchimento do db

# preserva, se existir, o arquivo da série de concursos baixado anteriormente
[[ -e $html ]] && mv $html $html~

printf '\n-- Baixando arquivo remoto.\n'

# download do arquivo html da série temporal dos concursos
# Nota: Não é possível usar time_stamping e cache.
wget --default-page=$html -o wget.log --remote-encoding=utf8 http://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil/\!ut/p/a1/04_Sj9CPykssy0xPLMnMz0vMAfGjzOLNDH0MPAzcDbz8vTxNDRy9_Y2NQ13CDA0sTIEKIoEKnN0dPUzMfQwMDEwsjAw8XZw8XMwtfQ0MPM2I02-AAzgaENIfrh-FqsQ9wBmoxN_FydLAGAgNTKEK8DkRrACPGwpyQyMMMj0VAcySpRM\!/dl5/d5/L2dBISEvZ0FBIS9nQSEh/pw/Z7_HGK818G0K85260Q5OIRSC42046/res/id=historicoHTML/c=cacheLevelPage/=/

# restaura o arquivo e aborta execução do script se o download foi mal sucedido
if [[ ! -e $html ]]; then
  printf '\nAviso: Não foi possível baixar o arquivo remoto.\n\n'
  [[ -e $html~ ]] && mv $html~ $html
  exit 1
fi

if [[ ! -e $dbname ]]; then
  printf '\n-- Criando o db.\n'
  sqlite3 $dbname <<EOT
.read sql/monta.sql
.read sql/param.sql
EOT
fi

xpath() {
  xidel $html -s --xpath "$1"
}

# extrai o número do concurso mais recente registrado no html
n=$(xpath 'html/body/table/tbody/tr[last()]/td[1]')

# contabiliza a quantidade de concursos registrados no html
m=$(xpath 'count(html/body/table/tbody/tr[@bgcolor])')

# checa a sequência dos números seriais dos concursos no html
if (( n > m )); then
  # monta o array dos números seriais dos concursos
  read -d' ' -a z <<< $(xpath 'html/body/table/tbody/tr[@bgcolor]/td[1]')
  r=$(( n-m ))
  printf '\nAviso: %d registros ausentes no html:\n\n' $r
  # pesquisa componentes ausentes na frente do array
  for (( j=1; j<${z[0]}; j++, r-- )); do printf ' %04d' $j; done
  # pesquisa componentes ausentes dentro do array
  for (( i=0; r>0 && i<m-1; i++ )); do
    for (( j=${z[i]}+1; j<${z[i+1]}; j++, r-- )); do printf ' %04d' $j; done
  done
  printf '\n'
  unset z     # elimina o array dos números
fi

# requisita o número do concurso mais recente registrado ou "zero" se db vazio
m=$(sqlite3 $dbname 'select case when count(1) then concurso else 0 end from ( select concurso from concursos order by data_sorteio desc limit 1 )')

if (( n > m )); then

  printf '\n-- Extraindo dados dos concursos.\n'

  # extrai do html baixado os dados dos concursos – exceto dos acertadores – que
  # são armazenados num arquivo text/plain conveniente para importação no SQLite
  xpath "html/body/table/tbody/tr[@bgcolor and td[1]>$m] / string-join((td[1], string-join((substring(td[2],7), substring(td[2],4,2), substring(td[2],1,2)), '-'), td[position()>2 and 18>position()], translate(td[18], ',.', '.'), td[19], td[position()>20 and 25>position()], translate(string-join(td[position()>24 and 33>position()], '|'), ',.', '.')), '|')" > $concursos

  # contabiliza o número de acertadores a partir do concurso mais antigo não
  # registrado, dado que o db pode estar desatualizado a mais de um concurso
  n=$(xpath "sum(html/body/table/tbody/tr[@bgcolor and td[1]>$m]/td[19])")

  if (( n > 0 )); then
    printf '\n-- Extraindo dados dos acertadores.\n'
    # extrai do html baixado somente dados dos acertadores, que são armazenados
    # num arquivo text/plain conveniente para importação no db SQLite
    xpath "html/body/table/tbody/tr[@bgcolor and td[1]>$m and td[19]>0]/td[20]/table/tbody/tr / concat(ancestor::tr[@bgcolor]/td[1], '|', upper-case(concat(if (string-length(td[1])=0) then 'NULL' else td[1], '|', if (string-length(td[2])=0) then 'NULL' else td[2])))" > $ganhadores
  else
    > $ganhadores   # cria arquivo vazio que evita erro ao importar dados
  fi

  printf '\n-- Preenchendo o db.\n'

  # preenche as tabelas dos concursos e dos acertadores com os dados extraídos
  sqlite3 $dbname <<EOT
.import $concursos concursos
.import $ganhadores ganhadores
EOT

fi

# notifica o número serial e data do concurso mais recente no db
read n s <<< $(sqlite3 -separator ' ' $dbname 'select concurso, data_sorteio from concursos order by concurso desc limit 1')
printf '\nConcurso mais recente no DB: %04d em %s.\n\n' $n "$(long_date $s)"

# pesquisa e notifica reincidência da combinação das bolas sorteadas mais
# recente na série histórica dos concursos
m=$(sqlite3 $dbname "with cte(N) as (select bolas from bolas_juntadas where concurso == $n) select count(1) from bolas_juntadas, cte where bolas == N")
(( m > 1 )) && printf 'Nota: A combinação das bolas sorteados %s\n\n' "ocorreu $m vezes!"
