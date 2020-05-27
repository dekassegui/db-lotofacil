#!/usr/bin/Rscript --no-init-file

# Script para análise a priori dos tempos de espera das premiações de 1+ apostas
# de acertadores das 15 bolas na série histórica de concursos da Lotofácil.

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite

source("R/param.R")   # checa disponibilidade da tabela "param" + atualização

library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data
library(RcmdrMisc)  # r-cran-rcmdr  <-- GNU R package for miscellaneous Rcmdr utilities

con <- dbConnect(SQLite(), 'loto.sqlite')

dbExecute(con, 'update param set status=1 where comentario glob "premio*"')

# sequência dos tempos de espera por concurso com 1+ acertadores das 15 bolas
# (evento premiação) na série histórica de concursos, onde:
#
#   ndx <-- número de ordem na sequência
#   fim <-- número serial do concurso com 1+ acertadores das 15 bolas
#   len <-- quantidade de concursos até premiação
#
dat <- dbReadTable(con, 'esperas')

dbDisconnect(con)

cat('Tempo de espera por 1º sucesso (1+ acertadores dos 15 números)\n\n')

# estimativa (de máxima verossimilhança) da probabilidade de premiação
n.premiacoes <- length(dat$ndx)
n.concursos <- dat[n.premiacoes,]$fim
p.sucesso <- round(n.premiacoes/n.concursos, 2)

cat(sprintf("H0: probabilidade de sucesso = %4.2f\n", p.sucesso))
# teste binomial exato da probabilidade de premiação
teste <- binom.test(n.premiacoes, n.concursos, alternative="two", p=p.sucesso)
print(teste)

options(warn=-1)

# teste de aderência do tempo de espera por premiação ~ Geométrica(p) usando
# a estimativa da probabilidade de premiação como parâmetro p
teste <- goodfit(
  dat$len-1,        # adequação para Binomial_negativa(1, p) = Geometrica(p)
  type='nbinomial',
  par=list(
    size=1,
    prob=p.sucesso
  )
)

cat(sprintf('HØ: Tempo de espera por 1º sucesso ~ Geom(%4.2f)\n', p.sucesso))
summary(teste)
cat('\n')

out <- capture.output(summary(teste))
fit.pvalue <- as.numeric(sub(".+ ", "", out[grep("Pearson", out)]))

fname <- "img/premiacao.png"
png(filename=fname, width=600, height=600, pointsize=18, family="Roboto Condensed")

par(
  mar=c(4, 4.5, 4, 1), mgp=c(3, .75, 0),
  fg="slateblue", cex.main=1.5, col.main="darkblue",
  cex.lab=1.25, col.lab="slateblue", font.lab=2,
  col.axis="gray20", font.axis=2
)

plotDistr(
  0:3, pgeom(0:3, p.sucesso), cdf=T, discrete=T,
  main=sprintf("ECDF x CDF da Geométrica(%4.2f)", p.sucesso),
  ylab="probabilidade", xlab="",
  bty='n', xaxt="n", yaxt="n", lwd=2, ylim=c(.9, 1)
)
plot(ecdf(dat$len-1), add=T, col="red")

title(xlab="tempo de espera por 1º sucesso", mgp=c(2.125, .75, 0))

a <- par('usr')
rect(a[1], a[3], a[2], a[4], col='transparent', border='gray33') # box frame

axis(side=1, 0:3, col="black")
axis(side=2, seq(.9, 1, .02), col="black", las=1)

text(
  sprintf("Fit: p.value = %6.4f", fit.pvalue),
  x=1.5, y=.91, adj=c(.5, .5), col="steelblue", cex=2.5
)

par(fg="gray33")  # cor do frame da legenda e textos

legend(
  "topright", inset=c(.05, .1), legend=c("ECDF", "CDF"),
  bg="#fcfcfc", col=c("red", "slateblue"), lty="solid", lwd=2
)

dev.off()

system(paste('display', fname))
