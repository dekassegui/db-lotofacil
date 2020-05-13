#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

con <- dbConnect(SQLite(), "loto.sqlite")

if (!dbExistsTable(con, "incidencias")) stop('Erro: consulta "incidencias" não existe no db.\n\n\tExecute o script "scripts/add-incidencias.sh" na linha de comando.\n\n')

bolas <- 1:25   # sequência da numeração das bolas

# Atualização automática das sequências de incidências das bolas armazenadas na
# tabela "param", inserindo os registros inexistentes e finalmente, imprime o
# conteúdo da tabela.
(function () {
  fmt <- c("insert into param (s, comentario) select group_concat(bolas>>(%1$d-1)&1, ''), 'incidências da bola %1$d' from bolas_juntadas", "update param set s=(select group_concat(bolas>>(%1$d-1)&1, '') from bolas_juntadas) where comentario glob '* %1$d'")
  for (bola in bolas) {
    n <- 1+dbGetQuery(con, sprintf("select exists(select 1 from param where comentario glob '* %d')", bola))[1,1]
    dbExecute(con, sprintf(fmt[n], bola))
  }
  # resumo do conteúdo
  cat('\nTabela "param":\n\n')
  print(dbGetQuery(con, "select printf('%2d', rowid) as rowid, comentario, substr(s, 1, 10)||'…'||substr(s, -10) as s, length(s) as len, status from param"))
  cat("\n")
})()

resumo <- data.frame(bolas, bolas, bolas, bolas, bolas)
colnames(resumo) <- c("full.count", "count", "media", "desvio", "maximo")
rownames(resumo) <- sprintf("BOLA_%02d", bolas)

cat("Processando")

for (bola in bolas) {
  cat('.')
  # torna incumbente, o registro da bola na tabela "param"
  dbExecute(con, sprintf("update param set status=1 where comentario glob '* %d'", bola))
  # carrega dados da bola
  dat <<- dbReadTable(con, 'incidencias')
  # armazena convenientemente as estatísticas
  resumo[bola,]$full.count <- length(dat$len)
  # exclui observações com número de sucessos igual a um
  dat <<- dat[dat$len>1,]
  resumo[bola,]$count <- length(dat$len)
  resumo[bola,]$media <-  mean(dat$len)
  resumo[bola,]$desvio <- sd(dat$len)
  resumo[bola,]$maximo <- max(dat$len)
}

cat('finalizado.\n\nComprimentos de sequências de "2+ sucessos" consecutivos:\n\n')

print(resumo[,2:5])
