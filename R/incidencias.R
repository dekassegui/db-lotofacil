#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), "loto.sqlite")

if (!dbExistsTable(con, "incidencias")) stop('Erro: consulta "incidencias" não existe no db.\n\n\tExecute o script "scripts/add-incidencias.sh" na linha de comando.\n\n')

cat("Processando")

bolas <- 1:25   # sequência da numeração das bolas

lista <- list(type="vector", 25)  # lista dos comprimentos das sequências
                                  # de 1+ sucessos consecutivos

# Atualização automática das sequências de incidências das bolas armazenadas na
# tabela "param", inserindo registros inexistentes se necessáro, alistando os
# comprimentos das sequências de 1+ sucessos das bolas, então resume a tabela
fmt <- c("insert into param (s, comentario, status) select group_concat(bolas>>(%1$d-1)&1, ''), 'incidências da bola %1$d', 1 from bolas_juntadas", "update param set s=(select group_concat(bolas>>(%1$d-1)&1, '') from bolas_juntadas), status=1 where comentario glob '* %1$d'")
for (bola in bolas) {
  cat(".")
  n <- 1+dbGetQuery(con, sprintf("select exists(select 1 from param where comentario glob '* %d')", bola))[1, 1]
  dbExecute(con, sprintf(fmt[n], bola))
  # carrega os comprimentos das sequências de 1+ sucessos consecutivos
  lista[[bola]] <- dbReadTable(con, 'incidencias')$len
}
names(lista) <- sprintf("BOLA_%02d", bolas)
cat('finalizado.\n\n')
# resumo do conteúdo da tabela "param"
cat('Tabela "param":\n\n')
print(dbGetQuery(con, "select printf('%2d', rowid) as rowid, comentario, substr(s, 1, 10)||'…'||substr(s, -10) as s, length(s) as len, status from param"))
cat("\n")

resumo <- data.frame(bolas, bolas, bolas, bolas, bolas)
colnames(resumo) <- c("count", "media", "desvio", "maximo", "2+")
rownames(resumo) <- names(lista)
resumo$count <- sapply(lista, length)
resumo$media <- sapply(lista, mean)
resumo$desvio <- sapply(lista, sd)
resumo$maximo <- sapply(lista, max)
resumo[,c("2+")] <- sapply(lista, function(x){ length(x[x>1]) })
cat("Comprimentos de sequências 1+ sucessos:\n\n")
print(resumo)

cat("\nH0: As sequências tem a mesma distribuição de frequências.\n")
kr <- kruskal.test(lista)
print(kr)
cat('Conclusão:', ifelse(kr$p.value >= .05, "não", ""),
  "rejeitamos a hipótese nula ao nível de significância de 5%.\n\n")

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
  lista, names=sprintf("%02d", bolas),
  col=c("orange", "gold"), border=c("orangered", "sienna"), las=1,
  main="sequências de 1+ sucessos", xlab="bolas", ylab="número de concursos"
)
rug(side=2, 1:max(bp$out), ticksize=-.0125, lwd=.95)
dev.off()
system(paste('display ', fname))
