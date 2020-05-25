#!/usr/bin/Rscript --no-init-file

library(RSQLite)    # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)        # r-cran-vcd    <-- GNU R Visualizing Categorical Data

source("R/param.R")   # checa disponibilidade da tabela "param" + atualização

con <- dbConnect(SQLite(), "loto.sqlite")

bolas <- 1:25   # sequência da numeração das bolas

options(warn=-1)  # no warnings this time

# string para requisição paramétrica dos valores de "tempo de espera por
# NUMERO sucessos" na sequência do registro incumbente da tabela "param"
query <- "WITH uno AS (
  SELECT * FROM esperas
) SELECT a.ndx/$NUMERO AS ndx, a.fim, (
      SELECT SUM(len) FROM uno WHERE ndx BETWEEN a.ndx-$NUMERO+1 AND a.ndx
    ) AS len
  FROM (SELECT * FROM uno WHERE ndx%$NUMERO == 0) AS a"

# Retorna o objeto resultante do teste de aderência aplicado aos valores de
# tempo de espera por "n.sucessos", que também é parâmetro da distribuição de
# probabilidades ― binomial negativa ― da hipótese nula, além de "p.sucesso"
# que assume o valor default 15/25 se não fornecido.  Os valores de tempo de
# espera, obtidos por consulta ao db, ficam disponíveis no data.frame "dat".
gof <- function (n.sucessos, p.sucesso=3/5) {
  dat <<- dbGetQuery(con, query, param=list("NUMERO"=n.sucessos))
  goodfit(
    dat$len-n.sucessos, # adequação dos dados
    type="nbinomial",
    par=list(size=n.sucessos, prob=p.sucesso)
  )
}

# ----------------------------------------------------------------------------
# Pesquisa para cada bola, o parâmetro "número de sucessos" da distribuição
# binomial negativa ― também parametrizada com "p.sucesso" fixado em 15/25 ―
# a qual é a distribuição de probabilidades da hipótese nula do teste de
# aderência aplicado aos valores de "tempo de espera por número de sucessos",
# hipótese esta, que não deve ser rejeitada ao nível de significância de 5%.
# ----------------------------------------------------------------------------

cat('> Processando'); inicio <- Sys.time(); iter <- 0

esperas <- list(type="vector", 25)  # storage dos comprimentos observados dos
                                    # tempos de espera por primeiro sucesso

fit <- data.frame(bolas)  # storage dos p.value, tal que o número de ordem de
                          # cada coluna corresponde ao "número de sucessos"

mask <- 2^25-1  # representação bitwise do conjunto de bolas, inicialmente
                # completo, cujos valores de "tempo de espera" são avaliados
                # a cada iteração ― enquanto bola pertencer ao conjunto ―

try.sucessos <- 0   # "número de sucessos" experimentado a cada iteração

while ((mask > 0) && (try.sucessos < 8)) {
  # incrementa o número de sucessos experimentado
  try.sucessos <- try.sucessos+1
  # loop de avaliação das bolas
  for (bola in bolas)
    # checa se bola pertence ao conjunto
    if (bitwAnd(bitwShiftR(mask, bola-1), 1) == 1) {
      iter <- iter+1; cat('.')
      # torna incumbente, o registro da bola na tabela "param"
      dbExecute(con, sprintf("UPDATE param SET status=1 WHERE comentario GLOB '* %d'", bola))
      # aplica o teste de aderência aos valores de tempo de espera da bola
      teste <- gof(try.sucessos)
      # alista os valores observados de tempo de espera por primeiro sucesso
      if (try.sucessos == 1) { esperas[[bola]] <- dat$len }
      # captura o sumário do teste recém aplicado
      output <- capture.output(summary(teste))
      # extrai o valor do p.value via teste de aderência de Neyman Pearson
      pvalue <- as.numeric(sub(".+ ", "", output[grep("Pearson", output)]))
      # armazena convenientemente o p.value
      fit[bola, try.sucessos] <- pvalue
      # exclui a bola do conjunto se o valor do p.value é maior igual que o
      # nível de significância ou seja; não há evidências estatísticas para
      # rejeição da hipótese nula do teste de aderência, portanto aceitamos que
      # o tempo de espera da "bola" segue distribuição "binomial negativa" com
      # parâmetros "n.sucessos" igual ao valor de try.sucessos e "p.sucesso"
      # igual a 15/25
      if (pvalue >= .05) mask <- bitwAnd(mask, bitwNot(bitwShiftL(1, bola-1)))
    }
}

cat('finalizado.\n\n #iterações:', iter, '\n  exec_time:', difftime(Sys.time(), inicio, units="sec"), '\n\n')

colnames(fit) <- sprintf("SIZE=%d", 1:try.sucessos)
rownames(fit) <- sprintf("BOLA_%02d", bolas)

cores <- rep_len(c('#ffcc66', '#aaffaa'), 25)
borda <- rep_len(c('#ff0000', '#009900'), 25)

cat('Bolas agrupadas pelo parâmetro "número de sucessos" da distribuição de\nprobabilidades de seus tempos de espera ~ Binomial negativa(n.sucessos, 0.6).\n')
for (n in 1:try.sucessos) {
  elenco <- which(fit[, n] >= .05)
  if (length(elenco) > 0) {
    cat('\n n.sucessos =', n, '-->', elenco, '\n')
    # modifica a cor da borda e de preenchimento do box para outra com opacidade
    # proporcional ao parâmetro "número de sucessos" constatado, que implica bom
    # ajuste de alguma sequência à distribuição Binomial negativa
    if (n > 1) {
      borda[elenco] <- "gray11"
      cores[elenco] <- sprintf("#9966ff%02x", trunc(255/n))
    }
  }
}

png(
  filename="img/estocastico.png", width=700, height=700,
  family="Roboto Condensed", pointsize=16
)

par(
  mar=c(5.25, 3.75, 2.5, 1), mgp=c(2.3125, .75, 0), fg="dimgray",
  cex.main=1.5, col.main="slategray4", cex.lab=1.25, font.lab=2,
  col.lab="slategray4", cex.axis=1.125, font.axis=2, col.axis="gray10"
)

boxplot(
  esperas, names=sprintf("%02d", bolas), las=1, col=cores, border=borda,
  pch=18, pars=list(whisklty='solid', boxwex=.6, outcex=.8), xlab="bolas",
  ylab="número de concursos", main="tempo de espera por 1º sucesso"
)
rug(side=2, seq.int(1, 13, 2), ticksize=-.0125, lwd=.9)

mtext(
  "bom ajuste \u21d4 número de sucessos ≥ 2", col="#9966ff", font=2, cex=1.125,
  side=1, at=26.5, line=4, adj=1
)

dev.off()

cat("\nHØ: Sequências observadas de tempo de espera por primeiro sucesso têm a mesma distribuição de valores.\n")
kr <- kruskal.test(esperas)
print(kr)
