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

# nome do arquivo local container da série de concursos, baixado a cada execução
# e preservado até a seguinte como backup
html="resultados.html"

# preserva – se existir – o doc html da série de concursos baixado anteriormente
[[ -e $html ]] && mv $html $html~

printf '\n-- Baixando arquivo remoto.\n'

# download do doc html da série de concursos mais recente, armazenado em "$html"
# Nota: Não é possível usar "time stamping" e "cache".
wget --default-page=$html -o wget.log --remote-encoding=utf8 http://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil/\!ut/p/a1/04_Sj9CPykssy0xPLMnMz0vMAfGjzOLNDH0MPAzcDbz8vTxNDRy9_Y2NQ13CDA0sTIEKIoEKnN0dPUzMfQwMDEwsjAw8XZw8XMwtfQ0MPM2I02-AAzgaENIfrh-FqsQ9wBmoxN_FydLAGAgNTKEK8DkRrACPGwpyQyMMMj0VAcySpRM\!/dl5/d5/L2dBISEvZ0FBIS9nQSEh/pw/Z7_HGK818G0K85260Q5OIRSC42046/res/id=historicoHTML/c=cacheLevelPage/=/

# restaura o arquivo e aborta execução se o download foi mal sucedido
if [[ ! -e $html ]]; then
  printf '\nAviso: Não foi possível baixar o arquivo remoto.\n\n'
  [[ -e $html~ ]] && mv $html~ $html
  exit 1
fi

printf '\n-- Ajustando o doc html.\n'

# ajusta o conteúdo do doc html recém baixado que é armazenado num novo doc html
tidy -config tidy.cfg $html | sed -ru -f scripts/clean.sed > concursos.html

if [[ ! -e loto.sqlite ]]; then
  printf '\n-- Criando o db.\n'
  sqlite3 loto.sqlite <<EOT
.read sql/monta.sql
.read sql/param.sql
EOT
fi

n=$(xmllint --html --xpath "count(//table/tr[count(td)>2])" concursos.html)
m=$(sqlite3 loto.sqlite "select count(1) from concursos")

if (( $n > $m )); then

  printf '\n-- Extraindo dados dos concursos.\n'

  # extrai os dados dos concursos – exceto detalhes sobre acertadores –
  # transformando o doc html ajustado em arquivo text/plain conveniente para
  # importação de dados no sqlite
  xsltproc -o concursos.dat --html --stringparam SEPARATOR "|" --param OFFSET $((m+1)) scripts/concursos.xsl concursos.html

  # contabiliza o número de acertadores a partir do concurso mais antigo não
  # registrado, dado que o db pode estar desatualizado a mais de um concurso
  n=$(xmllint --html --xpath "sum(//table/tr[count(td)>2][td[1]>$m]/td[19]/text())" concursos.html)
  if (( $n > 0 )); then
    printf '\n-- Extraindo dados dos acertadores.\n'
    # repete o passo anterior extraindo somente os dados sobre os acertadores
    xsltproc -o ganhadores.dat --html --stringparam SEPARATOR "|" --param OFFSET $((m+1)) scripts/ganhadores.xsl concursos.html
  else
    # cria arquivo vazio com time stamp do arquivo baixado
    > ganhadores.dat
    touch -r $html ganhadores.dat
  fi

  printf '\n-- Preenchendo o db.\n'

  # preenche as tabelas dos concursos e dos acertadores com os respectivos dados
  # recém extraídos
  sqlite3 loto.sqlite <<EOT
.import concursos.dat concursos
.import ganhadores.dat ganhadores
EOT

fi

# notifica o usuário sobre o concurso mais recente armazenado no db
sqlite3 loto.sqlite "select x'0a' || printf('Concurso registrado mais recente: %s em %s', concurso, strftime('%d-%m-%Y', data_sorteio)) || x'0a' from concursos order by concurso desc limit 1"
