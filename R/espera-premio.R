library(RSQLite)
con <- dbConnect(SQLite(), 'loto.sqlite')

# sequência dos tempos de espera por premiação (de 1+ acertadores das 15 bolas)
# na série histórica de concursos, onde:
#
#   ndx --> número de ordem na sequência
#   fim --> número serial do concurso que premiou 1+ acertadores das 15 bolas
#   len --> quantidade de concursos até ocorrer premiação
#
dat <- dbGetQuery(con, 'select ndx, fim, len from espera')

dbDisconnect(con)

# teste de aderência do tempo de espera por premiação ~ Geométrica(p) tal que a
# probabilidade de sucesso "p" é estimada via método de máxima verossimilhança
# aplicado às observações
gof <- vcd::goodfit(
  table(dat$len-1),                   # contagem do número de falhas até sucesso
  type='nbinomial',                   # adequada para binomial negativa, tal que
  par=list(                           # Binomial_negativa(1, p) == Geometrica(p)
    size=1,                               # número de sucessos característico
    prob=length(dat$ndx)/tail(dat$fim, 1) # estimativa a priori
  )
)

cat(sprintf('\nHØ: Tempo de espera por premiação ~ Geom(%7.5f)', gof$par$prob), '\n')

summary(gof)

# plot(gof)
