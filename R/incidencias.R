#!/usr/bin/Rscript --no-init-file

# Pesquisa preliminar das sequências de 1+ sorteios de bolas na série histórica
# de concursos da Lotofácil.

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

source("R/param.R")   # checa disponibilidade da tabela "param" + atualização

con <- dbConnect(SQLite(), "loto.sqlite")

showParam(con)

bolas <- 1:25   # sequência da numeração das bolas

# lista dos comprimentos das sequências de 1+ sucessos consecutivos
lista <- lapply(bolas, function(bola){
  dbExecute(con, sprintf('update param set status=1 where comentario glob "* %d"', bola))
  dbReadTable(con, 'incidencias')$len
})
names(lista) <- sprintf("BOLA_%02d", bolas)

resumo <- data.frame(bolas, bolas, bolas, bolas, bolas)
colnames(resumo) <- c("count", "media", "desvio", "maximo", "2+")
rownames(resumo) <- names(lista)
resumo$count <- sapply(lista, length)
resumo$media <- sapply(lista, mean)
resumo$desvio <- sapply(lista, sd)
resumo$maximo <- sapply(lista, max)
resumo[,c("2+")] <- sapply(lista, function(x){ length(x[x>1]) })
cat("Comprimentos de sequências de 1+ sucessos:\n\n")
print(resumo)

cat("\nH0: Os grupos tem a mesma distribuição de valores.\n")
kr <- kruskal.test(lista)
print(kr)
cat('Conclusão:', ifelse(kr$p.value >= .05, "Não rejeitamos", "Rejeitamos"),
  "a hipótese nula ao nível de significância de 5%.\n\n")

fname="img/repeticoes.png"
png(
  filename=fname, width=600, height=600,
  family="Roboto Condensed", pointsize=18
)
par(
  mar=c(4, 4, 3, 1), mgp=c(2.5, .75, 0), fg="slategray",
  cex.main=1.25, col.main="slateblue4",
  cex.lab=1.125, font.lab=2, col.lab="slateblue4",
  font.axis=2, col.axis="gray10"
)
bp <- boxplot(
  lista, names=sprintf("%02d", bolas), col=c("orange", "gold"),
  border=c("red", "darkred"), las=1, pch=16, pars=list(outcex=.625),
  main="comprimentos de sequências de 1+ sucessos", xlab="bolas", ylab="número de concursos"
)
rug(side=2, 1:max(bp$out), ticksize=-.0125, lwd=.95)
dev.off()
system(paste('display ', fname))
