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

declare -r dirty=resultados.html      # arquivo da série temporal de concursos
                                      # baixada a cada execução e preservada até
                                      # a seguinte como backup
declare -r clean=concursos.html       # versão de $dirty válida no padrão HTML5
                                      # da W3C
declare -r dbname=loto.sqlite         # arquivo do db SQLite, opcionalmente
                                      # (re)criado, preenchido a cada execução
declare -r concursos=concursos.dat    # arquivo plain/text dos dados de
                                      # concursos para preenchimento do db
declare -r ganhadores=ganhadores.dat  # arquivo plain/text dos dados de
                                      # acertadores para preenchimento do db

# preserva, se existir, o arquivo da série de concursos baixado anteriormente
[[ -e $dirty ]] && mv $dirty $dirty~

printf '\n-- Baixando arquivo remoto.\n'

# download da série temporal dos concursos que é armazenada em $dirty
# Nota: Não é possível usar time_stamping e cache.
wget --default-page=$dirty -o wget.log --remote-encoding=utf8 http://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil/\!ut/p/a1/04_Sj9CPykssy0xPLMnMz0vMAfGjzOLNDH0MPAzcDbz8vTxNDRy9_Y2NQ13CDA0sTIEKIoEKnN0dPUzMfQwMDEwsjAw8XZw8XMwtfQ0MPM2I02-AAzgaENIfrh-FqsQ9wBmoxN_FydLAGAgNTKEK8DkRrACPGwpyQyMMMj0VAcySpRM\!/dl5/d5/L2dBISEvZ0FBIS9nQSEh/pw/Z7_HGK818G0K85260Q5OIRSC42046/res/id=historicoHTML/c=cacheLevelPage/=/

# restaura o arquivo e aborta execução do script se o download foi mal sucedido
if [[ ! -e $dirty ]]; then
  printf '\nAviso: Não foi possível baixar o arquivo remoto.\n\n'
  [[ -e $dirty~ ]] && mv $dirty~ $dirty
  exit 1
fi

printf '\n-- Ajustando o doc html.\n'

# ajusta o html armazenado em $dirty que torna-se válido no padrão HTML5 da W3C
# possibilitando consultas via XPath e extração de dados via XSLT
tidy -config tidy.cfg $dirty | sed -ru -f scripts/clean.sed > $clean

if [[ ! -e $dbname ]]; then
  printf '\n-- Criando o db.\n'
  sqlite3 $dbname <<EOT
.read sql/monta.sql
.read sql/param.sql
EOT
fi

xpath() {
  xmllint --html --xpath "$1" $clean
}

# extrai o número do concurso mais recente registrado no html
n=$(xpath '//body/table/tr[last()]/td[1]/text()')

# contabiliza a quantidade de concursos registrados no html
m=$(xpath 'count(//body/table/tr[td[32]])')

# checa a sequência de concursos registrados no html
if (( n > m )); then
  # monta a string que representa a lista dos números de concursos no html
  # usando único espaço em branco como prefixo e sufixo de cada número
  z=$(xpath '//body/table/tr[td[32]]/td[1]' | sed -ru 's/[^0-9]+/ /g')
  # prepara o array dos números de concursos omitidos
  declare -a missing
  # loop de pesquisa que preenche o array dos números dos concursos omitidos
  for (( i=0, j=n-m, k=1; j>0 && k<n; k++ )); do
    [[ $z =~ " $k " ]] && continue
    missing[$i]=$k    # inclusão do número do concurso omitido ao array
    (( --j, ++i ))    # atualização dos contadores
  done
  printf '\nAviso: Faltam %d registros no html:\n\n %s.\n' $i "${missing[*]}"
fi

# requisita o número do concurso mais recente registrado no db
m=$(sqlite3 $dbname "select concurso from concursos order by data_sorteio desc limit 1")

if (( $n > $m )); then

  printf '\n-- Extraindo dados dos concursos.\n'

  xslt() {
    xsltproc -o "$1" --html --stringparam SEPARATOR "|" --param OFFSET $((m+1)) "$2" $clean
  }

  # extrai os dados dos concursos – exceto dos acertadores – transformando o doc
  # html ajustado em arquivo text/plain conveniente para importação no SQLite
  xslt $concursos scripts/concursos.xsl

  # contabiliza o número de acertadores a partir do concurso mais antigo não
  # registrado, dado que o db pode estar desatualizado a mais de um concurso
  n=$(xpath "sum(//tr[td[1]>$m]/td[19])")

  if (( $n > 0 )); then
    printf '\n-- Extraindo dados dos acertadores.\n'
    # extrai somente dados dos acertadores, transformando o doc html ajustado
    # em arquivo text/plain conveniente para importação no db SQLite
    xslt $ganhadores scripts/ganhadores.xsl
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
sqlite3 $dbname "select x'0a' || printf('Concurso registrado mais recente: %s em %s', concurso, strftime('%d-%m-%Y', data_sorteio)) || x'0a' from concursos order by concurso desc limit 1"
