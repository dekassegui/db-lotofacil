#!/usr/bin/Rscript --no-init-file
#
# Diagrama de frequências e latências dos números sorteados na Lotofácil até o
# concurso mais recente - cujos dados estejam armazenados localmente - exibindo
# sumário de estatísticas de cada número, dos sorteios e do concurso.

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite
library(vcd)      # r-cran-vcd    <-- GNU R Visualizing Categorical Data

source("R/param.R")   # checa disponibilidade da tabela "param" + atualização

con <- dbConnect(SQLite(), "loto.sqlite")

# requisita o número do concurso mais recente e a proporção de premiações ao
# longo do tempo
loto <- dbGetQuery(con, "SELECT m AS concurso, cast(n AS real)/m AS premiacao FROM (SELECT max(concurso) AS m, sum(ganhadores_15_numeros>0) AS n FROM concursos)")

# requisita os 12 concursos mais recentes e respectivos status de premiação
concursos <- dbGetQuery(con, paste("SELECT concurso, ganhadores_15_numeros>0 AS premiado FROM concursos WHERE concurso >= ", loto$concurso-12+1))

# requisita frequências, latências e atipicidades dos números no concurso mais recente
numeros <- dbGetQuery(con, "SELECT frequencia, latencia, atipico FROM info_bolas ORDER BY bola")

bolas <- 1:25

numeros$maxLatencia <- sapply(bolas, function (bola) {
  dbExecute(con,
    sprintf("UPDATE param SET status=1 WHERE comentario glob '* %d'", bola))
  dbGetQuery(con, "SELECT max(len)-1 FROM esperas")[1, 1]
})

# requisita os números sorteados no concurso anterior ao mais recente
anterior <- dbGetQuery(con, paste("SELECT bola FROM bolas_sorteadas WHERE concurso+1 ==", loto$concurso))

# requisita tempos de espera por concursos com premiação
esperas <- dbGetQuery(con, "SELECT len FROM espera")

dbDisconnect(con)
rm(con)

# testa HØ: números ~ U(1, 25)
teste <- chisq.test(numeros$frequencia, correct=F)
x <- ifelse(teste$p.value >= .05, 1, 2)

# testa HØ: tempos de espera por concurso com premiação ~ Geométrica(p)
teste <- goodfit(
  table(esperas-1),   # tabela de contingência das latências, adequada
  type="nbinomial",   # para Binomial_negativa(1, p) == Geometrica(p)
  par=list(
    size=1,
    prob=loto$premiacao
  )
)
texto <- capture.output(summary(teste))
pvalue <- as.numeric(sub(".+ ", "", texto[grep("Pearson", texto)]))
y <- ifelse(pvalue >= .05, 1, 2)

rm(esperas, teste, texto, pvalue)

numeros$corFundo <- "white"

five <- fivenum(numeros$frequencia)

cores <- colorRamp(c("#FFCC66", "orange1"), bias=1, space="rgb", interpolate="spline")
selecao <- which(numeros$frequencia>five[4])
numeros[selecao,]$corFundo <- rgb(cores((numeros[selecao,]$frequencia-five[4])/(five[5]-five[4])), max=255)

cores <- colorRamp(c("yellow1", "gold1"), bias=.75, space="rgb", interpolate="spline")
selecao <- which(numeros$frequencia>five[3] & numeros$frequencia<=five[4])
numeros[selecao,]$corFundo <- rgb(cores((numeros[selecao,]$frequencia-five[3])/(five[4]-five[3])), max=255)

cores <- colorRamp(c("#D0FFD0", "seagreen2"), bias=1, space="rgb", interpolate="spline")
selecao <- which(numeros$frequencia>five[2] & numeros$frequencia<=five[3])
numeros[selecao,]$corFundo <- rgb(cores((numeros[selecao,]$frequencia-five[2])/(five[3]-five[2])), max=255)

cores <- colorRamp(c("#ACECFF", "skyblue1"), bias=1, space="rgb", interpolate="spline")
selecao <- which(numeros$frequencia<=five[2])
numeros[selecao,]$corFundo <- rgb(cores((numeros[selecao,]$frequencia-five[1])/(five[2]-five[1])), max=255)

rm(five)

cores <- colorRampPalette(c("gray0", "gray10", "gray20", "gray80"))(25)
numeros$corFrente <- cores[rank(numeros$latencia, ties.method="last")]
# garante máxima tonalidade de cinza para números com mínima latência (=zero)
numeros[numeros$latencia == 0, "corFrente"] <- "black"

VC <- c(.67, .27); AR <- c(1, 1/2); AL <- c(0, 1/2)

# -- montagem do diagrama: HEADER --> FOOTER --> CONTEÚDO

png(filename="img/dia.png", width=500, height=600, bg="white", pointsize=10, family="Roboto")

layout(matrix(c(1, 3, 2), ncol=1, nrow=3), heights=c(10, 100, 10))

# -- HEADER --

par(mar=c(0, .75, 0.75, .75), family="Roboto", font=2, cex=1.25, xaxs="i", yaxs="i")

plot(NULL, type="n", axes=F, xlim=c(0, 5), ylim=c(0, 1), xlab="")

text(.02, .5, paste("Lotofácil", loto$concurso), adj=AL, col="gray15", family="Roboto Condensed", cex=3.125)

text(2.625, .70625, "premiações \u276A15 bolas\u276B recentes:", adj=AL, col="gray20")
cores <- colorRampPalette(c("lightblue", "royalblue"))(11); cores[12] <- "blue"
selecao <- which(!concursos$premiado)
cores[selecao] <- gray.colors(12, .87, .5)[selecao]
text(seq(2.575, by=.2, length.out=12), .26, rep.int("\u26AB", 12), adj=AL, col=cores, cex=2)
rm(cores, selecao)

# -- FOOTER --

par(mar=c(0.75, .75, 0, .75))

plot(NULL, type="n", axes=F, xlim=c(0, 5), ylim=c(0, 1), xlab="")

dat <- matrix(c("\uF00C", "\uF00D", "dodgerblue", "red"), ncol=2, byrow=T)
text(1.85, VC, c("números i.i.d. U\u276A1, 25\u276B", paste0("premiações ~ Geom\u276A", signif(loto$premiacao, 4), "\u276B")), adj=AR, col="gray20")
text(1.88, VC, c(dat[1, x], dat[1, y]), adj=AL, col=c(dat[2, x], dat[2, y]))
rm(dat)

# legenda das quadrículas

rect(2.40, 0, 4.54, 1, xpd=T, col="khaki1", border=NA) # background
text(2.50, VC, c("frequência", "latência"), adj=AL, col=c("darkred", "violetred"))
text(4.44, VC, c("Atípico\u2215Reincidente", "latência recorde"), adj=AR, col=c("black", "firebrick"))

# escala de cores das quadrículas

library(png)
degrade <- readPNG("img/degrade.png", native=TRUE)
rasterImage(degrade, 4.66, 0, 4.78, 1, interpolate=TRUE)
text(rep(c(4.84, 4.82), each=3), c(.225, .5, .775), adj=AL, col="black",
  cex=.8, c(expression(Q[1]), expression(Q[2]), expression(Q[3])))
rm(degrade)

# -- CONTEÚDO --

TL <- c(0, 1); TR <- c(1, 1); BL <- c(0, 0); BR <- c(1, 0); MID <- c(.5, .5)

par(mar=c(0.5, .75, 0.5, .75), family="Roboto Condensed", cex=1.375)

plot(NULL, type="n", axes=F, xlim=c(0, 5), ylim=c(0, 5), xlab="")

for (bola in bolas) {
  x <- (bola-1) %% 5
  y <- (bola-1) %/% 5
  attach(numeros[bola,])
  # renderiza a quadricula com cor em função da frequência
  rect(x, 4-y, x+1, 5-y, col=corFundo, border="white", lwd=1.5)
  # renderiza o número com cor em função da latência em relevo
  text(
    c(x+.51, x+.5), c(4.49-y, 4.5-y), sprintf("%02d", bola),
    adj=MID, col=c("white", corFrente), cex=3.125
  )
  # frequência histórica
  text(x+.1, 4.9-y, frequencia, adj=TL, col="darkred")
  # checa se frequência abaixo do esperado (frequencia < loto$concurso*15/25)
  # e latência acima do esperado (latencia >= 25/15)
  if (atipico) {
    text(x+.9, 4.9-y, "A", adj=TR, col="black")
  } else if (latencia == 0) {
    # renderiza borda extra para evidenciar número recém sorteado
    rect(
      x+.025, 4.025-y, x+.975, 4.975-y, col="transparent", border="black", lwd=2.5
    )
    # checa se número é reincidente -- sorteado no concurso anterior
    if (bola %in% anterior$bola) {
      text(x+.9, 4.9-y, "R", adj=TR, col="black")
    }
  }
  # latência imediata
  text(x+.1, 4.1-y, latencia, adj=BL, col="violetred")
  # máxima latência histórica
  text(x+.9, 4.1-y, maxLatencia, adj=BR, col="firebrick")
  detach(numeros[bola,])
}

dev.off()
