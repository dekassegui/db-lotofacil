#!/usr/bin/Rscript --no-init-file

# Atualização ou inclusão de registros na tabela "param" com dados – disponíveis
# localmente – do concurso mais recente.

library(RSQLite)

con <- dbConnect(SQLite(), 'loto.sqlite')

if (!dbExistsTable(con, "param")) stop('Esquema "param" não está disponível.\n\n\tExecute o script "scripts/param.sh" na linha de comando.\n\n')

sql <- c(
  'INSERT INTO param SELECT GROUP_CONCAT(bolas>>(%1$d-1)&1, ""), "bola %1$d", 0 FROM bolas_juntadas',
  'UPDATE param SET s=(SELECT GROUP_CONCAT(bolas>>(%1$d-1)&1, "") FROM bolas_juntadas) WHERE comentario GLOB "* %1$d"'
)
for (numero in 1:25) {
  j <- 1 + dbGetQuery(con, sprintf('SELECT EXISTS(SELECT 1 FROM param WHERE comentario GLOB "* %d")', numero))[1, 1]
  dbExecute(con, sprintf(sql[j], numero))
}

if (dbGetQuery(con, 'SELECT EXISTS(SELECT 1 FROM param WHERE comentario == "premio principal")')[1, 1] == 1) {
  sql <- 'UPDATE param SET s=(SELECT GROUP_CONCAT(ganhadores_15_numeros>0, "") FROM concursos) WHERE comentario == "premio principal"'
} else {
  sql <- 'INSERT INTO param SELECT GROUP_CONCAT(ganhadores_15_numeros>0, ""), "premio principal", 0 FROM concursos'
}
dbExecute(con, sql)

showParam <- function(conn) {
  # resumo do conteúdo da tabela "param"
  cat('Tabela "param":\n\n')
  print(dbGetQuery(conn, "SELECT PRINTF('%2d', rowid) AS rowid, comentario, SUBSTR(s, 1, 10)||'...'||SUBSTR(s, -10) AS s, LENGTH(s) AS len, status FROM param"))
  cat("\n")
}

dbDisconnect(con)

rm(con, sql, numero, j)
