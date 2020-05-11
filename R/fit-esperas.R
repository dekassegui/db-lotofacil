library(RSQLite)
library(vcd)

con <- dbConnect(SQLite(), "loto.sqlite")

# Atualização das sequências de incidências das bolas armazenadas na tabela
# "param", que a seguir é resumida.
(function () {
    fmt <- "update param set s=(
    select group_concat(bolas>>(%1$d-1)&1, '') from bolas_juntadas
  ) where comentario glob '* %1$d'"
    dbBegin(con)
    for (bola in 1:25) { dbExecute(con, sprintf(fmt, bola)) }
    dbCommit(con)
    cat('\nTabela "param":\n\n')
    print(dbGetQuery(con, "select rowid, comentario, length(s) as len, status from param"))
    cat("\n")
})()

options(warn=-1)

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
# probabilidades -- binomial negativa -- da hipótese nula, além de "p.sucesso"
# que assume o valor default 15/25 se não fornecido.  Os valores de tempo de
# espera, obtidos por consulta ao db, ficam disponíveis no data.frame "dat".
gof <- function (n.sucessos, p.sucesso=3/5) {
  dat <<- dbGetQuery(con, query, param=list("NUMERO"=n.sucessos))
  goodfit(
    dat$len-n.sucessos, # número de falhas
    type="nbinomial",
    par=list(size=n.sucessos, prob=p.sucesso)
  )
}

# ----------------------------------------------------------------------------
# Pesquisa para cada bola, o parâmetro "número de sucessos" da distribuição
# binomial negativa -- também parametrizada com "p.sucesso" fixado em 15/25 --
# a qual é a distribuição de probabilidades da hipótese nula do teste de
# aderência aplicado aos valores de "tempo de espera por número de sucessos",
# hipótese esta, que não deve ser rejeitada ao nível de significância de 5%.
# ----------------------------------------------------------------------------

fit <- data.frame(1:25) # storage dos p.value, onde o número de ordem de cada
                        # coluna corresponde ao "número de sucessos"

mask <- 2^25-1  # representação bitwise do conjunto de bolas, inicialmente
                # completo, cujos valores de "tempo de espera" são testados
                # a cada iteração -- enquanto pertencentes ao conjunto --

try.sucessos <- 0   # "número de sucessos" experimentado a cada iteração

while (mask > 0 && try.sucessos < 8) {
  # incrementa o número de sucessos experimentado
  try.sucessos <- try.sucessos+1
  # loop de avaliação das bolas
  for (bola in 1:25) {
    # pula a avaliação se a bola foi excluída do conjunto
    if (bitwAnd(bitwShiftR(mask, bola-1), 1) == 0) { next }
    # torna incumbente, o registro da bola na tabela "param"
    dbExecute(con,
      sprintf("update param set status=1 where comentario glob '* %d'", bola))
    # aplica o teste de aderência aos valores de tempo de espera da bola
    teste <- gof(try.sucessos)
    # captura o sumário do teste recém aplicado
    output <- capture.output(summary(teste))
    # extrai o valor do p.value via teste de aderência de Neyman Pearson
    pvalue <- as.numeric(sub(".+ ", "", output[grep("Pearson", output)]))
    # armazena convenientemente o p.value
    fit[bola, try.sucessos] <- pvalue
    # exclui a bola do conjunto se o valor do p.value é maior que o nível de
    # significância ou seja; não há evidências estatísticas para rejeição da
    # hipótese nula do teste de aderência, portanto aceitamos que o tempo de
    # espera da "bola" segue distribuição "binomial negativa" com parâmetros
    # n.sucessos igual ao valor de try.sucessos e "p.sucesso" igual a 15/25.
    if (pvalue > .05) { mask <- bitwAnd(mask, bitwNot(bitwShiftL(1, bola-1))) }
  }
}

colnames(fit) <- sprintf("SIZE=%d", 1:try.sucessos)