#!/usr/bin/Rscript --no-init-file

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), 'loto.sqlite')

# data frame dos concursos e respectivas bolas reincidentes
dat <- dbGetQuery(con, 'SELECT a.concurso, a.bola
  FROM bolas_sorteadas AS a JOIN bolas_sorteadas AS b
    ON (a.concurso-1 == b.concurso AND a.bola == b.bola)')

dbDisconnect(con)

possiveis <- c(5:15)  # quantidades possíveis de bolas reincidentes num concurso

frequencias <- tabulate(
    table(dat$concurso),  # frequências dos concursos distintos via contagem
                          # das bolas reincidentes em cada concurso
    nbins=15              # maior quantidade possível de bolas reincidentes
  )[possiveis]            # seleciona frequências possíveis

fname="img/reincidencias.png"

png(
  filename=fname, width=600, height=600, pointsize=16, family="Roboto Condensed"
)

par(
  mar=c(3.5, 3.7, 3, 1.5), mgp=c(2, .75, 0), las=1, fg="gray50",
  cex.main=1.475, col.main="navy",
  cex.lab=1.25, font.lab=2, col.lab="slateblue"
)

major=(max(frequencias)%/%50+1)*50  # maior valor representável no eixo x

barplot(
  frequencias, names.arg=possiveis, horiz=T, col=c('#33cc66', '#6666ff'),
  main=paste("Bolas Reincidentes nos", 1+sum(frequencias), "Concursos da Lotofácil"),
  ylab="número de bolas reincidentes",
  xlab="número de concursos", xlim=c(0, major), xaxt='n'
)
axis(side=1, seq(0, major, 100))
rug(side=1, seq(50, major, 100), ticksize=-.0125, lwd=1)

abline(v=seq(50, major, 50), lty="dotted", col='lightgray')

media <- sum(possiveis * frequencias) / sum(frequencias)  # média ponderada

text(
  sprintf("Média de %5.2f bolas reincidentes por concurso.", media),
  x=par("usr")[2]/2, y=par("usr")[4],
  adj=c(.5, 1), cex=1.35, font=2, col='#ff6600'
)

dev.off()

system(paste('display', fname))
