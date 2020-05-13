#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), "loto.sqlite")

if (!dbExistsTable(con, "esperas")) stop('Erro: consulta "esperas" não existe no db.\n\n\tExecute o script "scripts/add-esperas.sh" na linha de comando.\n\n')

bolas <- 1:25   # sequência da numeração das bolas

# Atualização automática das sequências de incidências das bolas armazenadas na
# tabela "param", inserindo os registros inexistentes e finalmente, imprime o
# conteúdo da tabela.
(function () {
  fmt <- c("insert into param (s, comentario) select group_concat(bolas>>(%1$d-1)&1, ''), 'incidências da bola %1$d' from bolas_juntadas", "update param set s=(select group_concat(bolas>>(%1$d-1)&1, '') from bolas_juntadas) where comentario glob '* %1$d'")
  for (bola in bolas) {
    n <- 1+dbGetQuery(con, sprintf("select exists(select 1 from param where comentario glob '* %d')", bola))[1,1]
    dbExecute(con, sprintf(fmt[n], bola))
  }
  # resumo do conteúdo
  cat('\nTabela "param":\n\n')
  print(dbGetQuery(con, "select printf('%2d', rowid) as rowid, comentario, substr(s, 1, 10)||'…'||substr(s, -10) as s, length(s) as len, status from param"))
  cat("\n")
})()

options(warn=-1)  # no warnings this time

# string para requisição parametrizada dos valores de "tempo de espera por
# NUMERO sucessos" na sequência do registro incumbente da tabela "param"
query <- "with uno as (
  select * from esperas
) select a.ndx/$NUMERO as ndx, a.fim, (
      select sum(len) from uno where ndx between a.ndx-$NUMERO+1 and a.ndx
    ) as len
  from (select * from uno where ndx%$NUMERO == 0) AS a"

# Retorna o objeto resultante do teste de aderência aplicado aos valores de
# tempo de espera por "n.sucessos", que também é parâmetro da distribuição de
# probabilidades ― binomial negativa ― da hipótese nula, além de "p.sucesso"
# que assume o valor default 15/25 se não fornecido.  Os valores de tempo de
# espera, obtidos por consulta ao db, ficam disponíveis no data.frame "dat".
gof <- function (n.sucessos, p.sucesso=3/5) {
  dat <<- dbGetQuery(con, query, param=list("NUMERO"=n.sucessos))
  goodfit(
    dat$len-n.sucessos, # adequação dos dados
    type="nbinomial",
    par=list(size=n.sucessos, prob=p.sucesso)
  )
}

# ----------------------------------------------------------------------------
# Pesquisa para cada bola, o parâmetro "número de sucessos" da distribuição
# binomial negativa ― também parametrizada com "p.sucesso" fixado em 15/25 ―
# a qual é a distribuição de probabilidades da hipótese nula do teste de
# aderência aplicado aos valores de "tempo de espera por número de sucessos",
# hipótese esta, que não deve ser rejeitada ao nível de significância de 5%.
# ----------------------------------------------------------------------------

cat('> Processando')
inicio <- Sys.time()
iter <- 0

fit <- data.frame(bolas)  # storage dos p.value, tal que o número de ordem de
                          # cada coluna corresponde ao "número de sucessos"

mask <- 2^25-1  # representação bitwise do conjunto de bolas, inicialmente
                # completo, cujos valores de "tempo de espera" são avaliados
                # a cada iteração ― enquanto bola pertencer ao conjunto ―

try.sucessos <- 0   # "número de sucessos" experimentado a cada iteração

while ((mask > 0) && (try.sucessos < 8)) {
  # incrementa o número de sucessos experimentado
  try.sucessos <- try.sucessos+1
  # loop de avaliação das bolas
  for (bola in bolas)
    # checa se bola pertence ao conjunto
    if (bitwAnd(bitwShiftR(mask, bola-1), 1) == 1) {
      iter <- iter+1
      cat('.')
      # torna incumbente, o registro da bola na tabela "param"
      dbExecute(con, sprintf("update param set status=1 where comentario glob '* %d'", bola))
      # aplica o teste de aderência aos valores de tempo de espera da bola
      teste <- gof(try.sucessos)
      # captura o sumário do teste recém aplicado
      output <- capture.output(summary(teste))
      # extrai o valor do p.value via teste de aderência de Neyman Pearson
      pvalue <- as.numeric(sub(".+ ", "", output[grep("Pearson", output)]))
      # armazena convenientemente o p.value
      fit[bola, try.sucessos] <- pvalue
      # exclui a bola do conjunto se o valor do p.value é maior igual que o
      # nível de significância ou seja; não há evidências estatísticas para
      # rejeição da hipótese nula do teste de aderência, portanto aceitamos que
      # o tempo de espera da "bola" segue distribuição "binomial negativa" com
      # parâmetros "n.sucessos" igual ao valor de try.sucessos e "p.sucesso"
      # igual a 15/25
      if (pvalue >= .05) {
        mask <- bitwAnd(mask, bitwNot(bitwShiftL(1, bola-1)))
      }
    }
}

cat('finalizado.\n\n #iterações:', iter, '\n  exec_time:', difftime(Sys.time(), inicio, units="sec"), '\n\n')

colnames(fit) <- sprintf("SIZE=%d", 1:try.sucessos)
rownames(fit) <- sprintf("BOLA_%02d", bolas)

cat('Bolas agrupadas pelo parâmetro "número de sucessos" da distribuição de\nprobabilidades de seus tempos de espera ~ Binomial negativa(n.sucessos, 0.6).\n')
for (n in 1:try.sucessos) {
  bolas <- which(fit[, n] >= .05)
  if (length(bolas) > 0) cat('\n n.sucessos =', n, '-->', bolas, '\n')
}
