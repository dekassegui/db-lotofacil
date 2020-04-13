#!/usr/bin/Rscript --slave --no-restore

library(RSQLite)
con <- dbConnect(SQLite(), dbname='loto.sqlite')

rs <- dbSendQuery(con, 'SELECT COUNT(*) AS NRECS FROM concursos')
nrecs = dbFetch(rs)$NRECS
dbClearResult(rs)

rs <- dbSendQuery(con, 'SELECT frequencia FROM info_bolas')
datum <- dbFetch(rs)

dbClearResult(rs)
dbDisconnect(con)

teste <- chisq.test(datum$frequencia, correct=FALSE)

cat('Frequências das bolas nos', nrecs, 'concursos da Lotofácil:\n')
cat('\n', datum$frequencia, '\n\n')
cat('Teste de Aderência Chi-square\n\n')
cat(' H0: As bolas têm distribuição uniforme.\n')
cat(' HA: As bolas não têm distribuição uniforme.\n')
cat(sprintf('\n\tX-square = %.4f', teste$statistic))
cat(sprintf('\n\t      df = %d', teste$parameter))
cat(sprintf('\n\t p-value = %.4f', teste$p.value))

if (teste$p.value > 0.05) action='Não rejeitamos' else action='Rejeitamos'
cat('\n\n', 'Conclusão:', action, 'H0 conforme evidências estatísticas.\n\n')
