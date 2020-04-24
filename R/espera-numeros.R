#!/usr/bin/Rscript --no-init-file

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)      # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), 'loto.sqlite')

# alocação da lista das sequências dos tempos de espera para cada NUMERO
latencias <- vector("list", 25)

# Query paramétrica para computar a sequência dos tempos de espera por concurso
# em que NUMERO foi sorteado, na série histórica de concursos, onde:
#
#   ndx --> número de ordem na sequência
#   fim --> número serial do concurso em que NUMERO foi sorteado
#   len --> quantidade de concursos até que NUMERO foi sorteado
#
query="with cte(s) as (
  select group_concat(bolas >> ($NUMERO-1) & 1, '') from bolas_juntadas
), ones(n, p) as (
  select 1, instr(s, '1') from cte
  union all
  select n+1, p+instr(substr(s, p+1), '1') as m from cte, ones where m > p
) select n as ndx, p as fim, p as len from ones where n == 1
  union all
  select t.n, t.p, t.p-z.p from ones as t join ones as z on t.n == z.n+1"

# loop para preenchimento da lista de sequências dos tempos de espera para cada
# NUMERO -- time expensive due to sql performance
rs <- dbSendQuery(con, query)
for (n in 1:25) {
  dbBind(rs, list('NUMERO'=n))
  latencias[[n]] <- dbFetch(rs)
  # cat(n, length(latencias[[n]]$len), tail(latencias[[n]]$fim, 1), '\n')
}
dbClearResult(rs)

dbDisconnect(con)

dat <- data.frame(sizes=sapply(latencias, function(it){ length(it$len) }))

dat$last <- sapply(latencias, function(it){ tail(it$fim, 1) })

dat$prop <- dat$sizes / dat$last

dat$maximas <- sapply(latencias, function(it){ max(it$len) })

dat$medias <- sapply(latencias, function(it){ mean(it$len) })

dat$desvio <- sapply(latencias, function(it){ sd(it$len) })

# executa o teste de aderência do tempo de espera por NUMERO ~ Geométrica(p)
# tal que a probabilidade de sucesso "p" é 15/25 = .6
teste <- function(NUMERO) {
  NUMERO=ifelse(NUMERO<1, 1, ifelse(NUMERO>25, 25, NUMERO))
  gof <- goodfit(
    table(latencias[[NUMERO]]$len-1), # contagem do número de falhas até sucesso
    type="nbinomial",                 # adequada para binomial negativa, tal que
    par=list(                         # Binomial_negativa(1, p) == Geometrica(p)
      size=1,
      prob=.6
    )
  )
  cat(sprintf('\nHØ: Tempo de espera da bola %d ~ Geom(%7.5f)', NUMERO, gof$par$prob), '\n')
  summary(gof)
  # plot(gof)
}

# extrai p-value dos testes de aderência em cada número
options(warn=-1)
dat$pvalue=-1
for (n in 1:25) { dat[n,]$pvalue=teste(n)[5] }
