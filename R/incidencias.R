#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), "loto.sqlite")

if (!dbExistsTable(con, "param")) stop('Esquema "param" não está disponível.\n\n\tExecute o script "scripts/param.sh" na linha de comando.\n\n')

cat("Processando")

bolas <- 1:25   # sequência da numeração das bolas

lista <- list(type="vector", 25)  # lista dos comprimentos das sequências
                                  # de 1+ sucessos consecutivos

# Atualização automática das sequências de incidências das bolas armazenadas na
# tabela "param", inserindo registros inexistentes se necessáro, alistando os
# comprimentos das sequências de 1+ sucessos das bolas, então resume a tabela
fmt <- c("INSERT INTO param (s, comentario, status) SELECT GROUP_CONCAT(bolas>>(%1$d-1)&1, ''), 'incidências da bola %1$d', 1 FROM bolas_juntadas", "UPDATE param SET s=(SELECT GROUP_CONCAT(bolas>>(%1$d-1)&1, '') FROM bolas_juntadas), status=1 WHERE comentario GLOB '* %1$d'")
for (bola in bolas) {
  cat(".")
  n <- 1 + dbGetQuery(con, sprintf("SELECT EXISTS(SELECT 1 FROM param WHERE comentario GLOB '* %d')", bola))[1, 1]
  dbExecute(con, sprintf(fmt[n], bola))
  # carrega os comprimentos das sequências de 1+ sucessos consecutivos
  lista[[bola]] <- dbReadTable(con, 'incidencias')$len
}
names(lista) <- sprintf("BOLA_%02d", bolas)
cat('finalizado.\n\n')
# resumo do conteúdo da tabela "param"
cat('Tabela "param":\n\n')
print(dbGetQuery(con, "SELECT PRINTF('%2d', rowid) AS rowid, comentario, SUBSTR(s, 1, 10)||'…'||SUBSTR(s, -10) AS s, length(s) AS len, status FROM param"))
cat("\n")

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
  filename=fname, width=700, height=700,
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