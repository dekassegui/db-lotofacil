#!/usr/bin/Rscript --no-init-file

library(RSQLite)

con <- dbConnect(SQLite(), 'loto.sqlite')

# requisita criação de tabela temporária das bolas reincidentes nos concursos
rs <- dbSendStatement(con, 'create temp table bolas_reincidentes as select a.concurso, a.bola from bolas_sorteadas as a join bolas_sorteadas as b on (a.concurso-1 == b.concurso and a.bola == b.bola)')
dbClearResult(rs)

# contagem dos concursos com mesmo número de bolas reincidentes
dat <- dbGetQuery(con, 'select n, count(concurso) as m from ( select concurso, count(bola) as n from bolas_reincidentes group by concurso ) group by n')

dbDisconnect(con)

png(
  filename="img/reincidencias.png", width=600, height=600, pointsize=16,
  family="Roboto Condensed"
)

par(
  mar=c(4.5, 4.5, 3.5, 2), las=1,
  cex.main=1.5, col.main="navy",
  cex.lab=1.25, font.lab=2, col.lab="slateblue"
)

upper=(max(dat$m)%/%50+1)*50

barplot(
  dat$m, names.arg=dat$n, horiz=T,
  main="Bolas Reincidentes nos Concursos da Lotofácil",
  ylab="número de bolas reincidentes",
  xlab="número de concursos",
  col=c('#33cc66', '#6666ff'), xlim=c(0, upper), xaxt='n'
)
axis(side=1, seq(0, upper, 100))
rug(side=1, seq(50, upper, 100), ticksize=-.0125, lwd=1)

media <- sum(dat$n * dat$m) / sum(dat$m)  # média ponderada

text(
  sprintf("Média de %5.2f bolas reincidentes por concurso.", media),
  x=par("usr")[2]/2, y=par("usr")[4],
  adj=c(.5, 1), cex=1.3, font=2, col='#ff6600'
)

dev.off()

system('display img/reincidencias.png')

