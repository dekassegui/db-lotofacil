#!/usr/bin/Rscript --no-init-file

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), 'loto.sqlite')

# Reincidência é evento em que um ou mais elementos arbitrários de conjunto
# finito são sorteados em concursos consecutivos. Na Lotofácil, a cada concurso
# são sorteadas 15 de 25 bolas distintas, portanto ocorre reincidência ao menos
# de 5 e no máximo de 15 bolas a partir do segundo concurso.

# data frame de ids seriais de concursos e respectivas bolas reincidentes
dat <- dbGetQuery(con, 'SELECT a.concurso, a.bola
  FROM bolas_sorteadas AS a JOIN bolas_sorteadas AS b
    ON (a.concurso-1 == b.concurso AND a.bola == b.bola)')

dbDisconnect(con)

n <- tail(dat$concurso, 1)
cat("Dados dos concursos 0001 a ", n, ".\n", sep="")

# tabula as frequências das bolas reincidentes na série histórica de concursos
tabela <- table(dat$bola)

cat('\nFrequências das bolas reincidentes:\n')
print(tabela)
cat(sprintf("\nmédia das frequências = %6.2f\n", mean(tabela)))

cat("\nH0: reincidências das bolas têm a mesma distribução.\n")
print(chisq.test(tabela))

possiveis <- 5:15   # quantidades possíveis de bolas reincidentes nos concursos

# contabiliza os concursos agrupados por quantidade de bolas reincidentes
# então seleciona os valores correspondentes às quantidades possíveis
frequencias <- tabulate(
    tabulate(dat$concurso), # conta as bolas reincidentes em cada concurso
    nbins=15                # número de grupos de concursos com mesma quantidade
                            # -- 1 a 15 -- de bolas reincidentes
  )[possiveis]              # seleção dos valores contabilizados

frequencias <- as.table(frequencias)
row.names(frequencias) <- possiveis
cat("\nFrequências dos concursos agrupados por quantidade de bolas reincidentes:\n\n")
print(frequencias)
media <- weighted.mean(possiveis, frequencias)
cat(sprintf("\nmédia da quantidade de bolas reincidentes por concurso = %6.4f\n\n", media))

fname="img/reincidencias.png"

png(
  filename=fname, width=600, height=600, pointsize=16, family="Roboto Condensed"
)

par(
  mar=c(3.5, 4, 4, 1), mgp=c(2.5, .75, 0), las=1, fg="gray50", font=2,
  cex.main=1.6, col.main="navy",cex.lab=1.25, font.lab=2, col.lab="slateblue",
  font.axis=2, col.axis='gray14'
)

major=(max(frequencias) %/% 50 + 1) * 50  # maior valor representável no eixo y

barplot(frequencias, col=c('#33cc66', '#6666ff'), ylim=c(0, major))

rug(side=2, seq(50, major, 100), ticksize=-.0125, lwd=1)  # submarcas da escala

abline(h=seq(50, major, 50), lty="dotted", col='gray88')  # linhas de referência

title(main="Reincidências nos Concursos da Lotofácil", line=2.3)
title(xlab="número de bolas reincidentes", line=2.1)
title(ylab="número de concursos")

mtext(
  sprintf("Média de %5.2f bolas reincidentes por concurso.", media),
  side=3, line=.4, adj=.5, cex=1.25, col='#ff6600'
)

text(
  paste('Dados: concursos 0001 a', n), srt=90, cex=1.125, col='gray25',
  xpd=T, x=par('usr')[2], y=par('usr')[4]/2, adj=c(.5, .5)
)

dev.off()

# system(paste('display', fname))
