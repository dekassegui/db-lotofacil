#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite

source("R/param.R")   # checa disponibilidade da tabela "param" + atualização

library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data
library(RcmdrMisc)  # r-cran-rcmdr  <-- GNU R package for miscellaneous Rcmdr utilities

con <- dbConnect(SQLite(), 'loto.sqlite')

# alocação da lista das sequências dos tempos de espera para cada NUMERO
esperas <- vector("list", 25)

# loop para preenchimento da lista de sequências dos tempos de espera para cada
# NUMERO -- time expensive due to sql performance
for (n in 1:25) {
  dbExecute(con, sprintf('update param set status=1 where comentario glob "* %d"', n))
  esperas[[n]] <- dbReadTable(con, 'esperas')
}

dbDisconnect(con)

# quantidade de vezes que cada "bola" foi sorteado ao longo da história
dat <- data.frame(sizes=sapply(esperas, function(it){ length(it$len) }))

# número serial do último concurso que cada "bola" foi sorteada
dat$last <- sapply(esperas, function(it){ tail(it$fim, 1) })

# percentual relativo de vezes que cada "bola" foi sorteada
dat$prop <- dat$sizes / dat$last

# probabilidade de sortear "bola" com número arbitrário num concurso onde são
# retiradas 15 bolas sem repetição entre 25 possíveis
p.sucesso=.6 # = 15/25

# testa igualdade entre si de todos os percentuais --> p1 = ... = p25
cat('\nH0: percentuais de vezes que cada "bola" foi sorteada são iguais.', '\n')
cat("p.value =", prop.test(dat$sizes, dat$last)$p.value, '\n')

# testa igualdade e valor de todos os percentuais --> p1 = ... = p25 = p.sucesso
cat('\nH0: percentuais de vezes que cada "bola" foi sorteada =', p.sucesso, '\n')
cat('p.value =', prop.test(dat$sizes, dat$last, p=rep(p.sucesso, 25))$p.value, '\n\n')

# p.value do teste binomial exato dos percentuais de sucesso estimado para cada número
dat$binom.pvalue <- sapply(1:25, function(n){ binom.test(dat[n,]$sizes, dat[n,]$last, p=p.sucesso, alternative="two")$p.value })

# maior tempo de espera de cada "bola" -- tamanho da subsequência mais longa
dat$maximas <- sapply(esperas, function(it){ max(it$len) })

# média do tempo de espera de cada "bola"
dat$medias <- sapply(esperas, function(it){ mean(it$len) })

# desvio padrão do tempo de espera de cada "bola"
dat$desvio <- sapply(esperas, function(it){ sd(it$len) })

options(warn=-1)

# executa o teste de aderência do tempo de espera por NUMERO ~ Geométrica(p)
gof <- function(NUMERO) {
  NUMERO=ifelse(NUMERO<1, 1, ifelse(NUMERO>25, 25, NUMERO))
  goodfit(
    table(esperas[[NUMERO]]$len-1), # tabela de contingência adequada tal que
    type="nbinomial",               # Binomial_negativa(1, p) = Geometrica(p)
    par=list(
      size=1,
      prob=p.sucesso
    )
  )
}

# extrai p-value dos testes de aderência em cada número
dat$fit.pvalue <- -1
for (n in 1:25) {
  teste <- gof(n)
  out <- capture.output(summary(teste))
  dat[n,]$fit.pvalue <- as.numeric(sub(".+ ", "", out[grep("Pearson", out)]))
}

plota <- function (numero) {
  fname <- sprintf("img/cdf%02d.png", numero)
  png(fname, width=640, height=640, family='Roboto', pointsize=16)
  par(
    mar=c(4, 4, 2, 1), fg='green3', font=2,
    col.main="#336699", col.lab="#3366ff"
  )

  # plotagem da ECDF das latências observadas × CDF Geométrica(.6)

  m <- dat[numero,]$maximas-1
  plotDistr(
    0:m, pgeom(0:m, p.sucesso), cdf=T, discrete=T,
    bty='n', lwd=3, ylim=c(0, 1), xlim=c(0, m), yaxt='n', xaxt='n',
    main=paste0('ECDF das Latências × CDF Geométrica(', p.sucesso, ')'),
    xlab='', ylab=''
  )
  plot(
    ecdf(esperas[[numero]]$len-1), add=T, verticals=T, col='darkviolet', pch=20
  )

  par(fg="gray20")
  title(xlab=sprintf('tempo de espera para N=%02d', numero), line=2.3)
  axis(side=1, seq.int(0, m, 2))
  rug(side=1, seq.int(1, m, 2), ticksize=-.0125, lwd=1)

  title(ylab='probabilidade', line=2.65)
  axis(side=2, seq(0, 1, .2), las=1)
  rug(side=2, seq(.1, .9, .2), ticksize=-.0125, lwd=1)

  a <- par('usr')
  rect(a[1], a[3], a[2], a[4], col='transparent', border='gray33')

  # identidade visual inequívoca do número
  text(
    sprintf("%02d", numero), x=m/2, y=.5, adj=c(.5, .5), cex=10, col='gray50'
  )
  # percentual da quantidade de vezes que a "bola" foi sorteada
  text(
    bquote(bold(hat(p)) == bold(.(sprintf("%5.4f", dat[numero,]$prop)))),
    x=m/2, y=.25, adj=c(.5, 0), cex=2.5, col='gray50'
  )

  # p-value do teste binomial exato do percentual da quantidade...
  text(
    sprintf("Binomial: p.value = %6.4f", dat[numero,]$binom.pvalue),
    x=m/2, y=.15, adj=c(.5, 0), cex=2, col=ifelse(dat[numero,]$binom.pvalue>=.05, "#0066ff", "red")
  )

  # p-value do teste de aderência do tempo de espera do número ~ Geométrica(.6)
  text(
    sprintf("Fit: p.value = %6.4f", dat[numero,]$fit.pvalue),
    x=m/2, y=.04, adj=c(.5, 0), cex=2, col=ifelse(dat[numero,]$fit.pvalue>=.05, "#0066ff", "red")
  )

  # legenda das CDFs conforme plotagem inicial
  legend(
    x=4*m/5, y=.8, legend=c("ECDF", "CDF"), bg="#fcfcfc",
    col=c("darkviolet", "green2"), lty="solid", lwd=3
  )

  dev.off()

  system(paste('display', fname))
}
