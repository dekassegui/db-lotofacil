#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data
library(RcmdrMisc)  # r-cran-rcmdr  <-- GNU R package for miscellaneous Rcmdr utilities

con <- dbConnect(SQLite(), 'loto.sqlite')

# sequência dos tempos de espera por concurso com 1+ acertadores das 15 bolas
# (evento premiação) na série histórica de concursos, onde:
#
#   ndx <-- número de ordem na sequência
#   fim <-- número serial do concurso com 1+ acertadores das 15 bolas
#   len <-- quantidade de concursos até premiação
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

print(gof)

cat(sprintf('\nHØ: Tempo de espera por premiação ~ Geom(%7.5f)', premiacao), '\n')
summary(gof)

output <- capture.output(summary(gof))
fit.pvalue <- as.numeric(sub(".+ ", "", output[grep("Pearson", output)]))

png(filename="img/premiacao.png", width=600, height=600, pointsize=18, family="Roboto Condensed")

par(
  mar=c(4, 4.5, 4, 1), mgp=c(3, .75, 0),
  fg="slateblue", cex.main=1.5, col.main="darkblue",
  cex.lab=1.25, col.lab="slateblue", font.lab=2,
  col.axis="gray20", font.axis=2
)

plotDistr(
  0:3, pgeom(0:3, premiacao), cdf=T, discrete=T,
  main=sprintf("ECDF x CDF da Geométrica(%5.4f)", premiacao),
  ylab="probabilidade", xlab="",
  bty='n', xaxt="n", yaxt="n", lwd=2, ylim=c(.9, 1)
)
plot(ecdf(dat$len-1), add=T, col="red")

title(xlab="tempo de espera na premiação", mgp=c(2.125, .75, 0))

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
