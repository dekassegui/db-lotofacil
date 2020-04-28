#!/usr/bin/Rscript --no-init-file

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)      # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), 'loto.sqlite')

# sequência dos tempos de espera por concurso com 1+ acertadores das 15 bolas
# (evento premiação) na série histórica de concursos, onde:
#
#   ndx --> número de ordem na sequência
#   fim --> número serial do concurso com 1+ acertadores das 15 bolas
#   len --> quantidade de concursos até premiação
#
dat <- dbGetQuery(con, 'select ndx, fim, len from espera')

dbDisconnect(con)

# estimativa (de máxima verossimilhança) da probabilidade de premiação
n.premiacoes=length(dat$ndx)
n.concursos=dat[n.premiacoes,]$fim
premiacao=n.premiacoes / n.concursos

# teste binomial exato da probabilidade de premiação
teste <- binom.test(n.premiacoes, n.concursos, alternative="two", p=premiacao)
print(teste)

# teste de aderência do tempo de espera por premiação ~ Geométrica(p) usando
# a estimativa da probabilidade de premiação como parâmetro p
gof <- goodfit(
  table(dat$len-1),   # tabela de contingência das latências das premiações
  type='nbinomial',   # adequada para Binomial_negativa(1, p) == Geometrica(p)
  par=list(
    size=1,
    prob=premiacao
  )
)

cat(sprintf('\nHØ: Tempo de espera por premiação ~ Geom(%7.5f)', premiacao), '\n')

summary(gof)
