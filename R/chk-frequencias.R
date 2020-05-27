#!/usr/bin/Rscript --slave --no-restore

# Teste da equiprobabilidade de sorteio das bolas, fundamentado nas frequências
# contabilizadas na série histórica de concursos.

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), dbname='loto.sqlite')

dat <- dbReadTable(con, 'bolas_sorteadas')

dbDisconnect(con)

teste <- chisq.test(table(dat$bola), correct=FALSE)

cat('\nFrequências das bolas nos', length(unique(dat$concurso)), 'concursos da Lotofácil:\n')
print(teste$observed)
cat('\n H0: As bolas são equiprováveis.', ' HA: As bolas não são equiprováveis.', '\n Teste de Aderência X² de Pearson', sprintf('\n\t%15s = %.4f\n\t%14s = %d\n\t%14s = %.4f', 'sample X²', teste$statistic, 'df', teste$parameter, 'p.value', teste$p.value), sep='\n')

if (teste$p.value > 0.05) action='Não rejeitamos' else action='Rejeitamos'
cat('\n Conclusão:', action, 'H0 conforme evidências estatísticas.\n\n')
