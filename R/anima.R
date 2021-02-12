#!/usr/bin/Rscript --no-init-file
#
# Script gerador de imagens do diagrama das frequências e latências dos números
# sorteados nos concursos, que serão quadros de animação via "ffmpeg" e da
# sequência dos quadros com respectivas durações (roteiro da animação) conforme
# configuração arbitrária, assim executado:
#
#   prompt> R/anima.R [concurso_inicial [concurso_final]]
#
library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), dbname='loto.sqlite')

CONCURSO_MAIS_RECENTE <- as.integer(dbGetQuery(con,
  'SELECT concurso FROM concursos ORDER BY concurso DESC LIMIT 1')[1, 1])

arguments <- commandArgs(TRUE)
if (length(arguments) == 0) {
  CONCURSO_INICIAL <- CONCURSO_MAIS_RECENTE-100+1
} else {
  arguments <- sort(as.numeric(arguments))
  if (length(arguments) == 1) {
    if (arguments[1] < 0) {
      CONCURSO_INICIAL <- CONCURSO_MAIS_RECENTE+arguments[1]+1
    } else {
      CONCURSO_INICIAL <- min(max(arguments[1], 1), CONCURSO_MAIS_RECENTE)
    }
  } else {
    CONCURSO_INICIAL <- max(arguments[1], 1)
    CONCURSO_MAIS_RECENTE <- min(max(arguments[2], 1), CONCURSO_MAIS_RECENTE)
  }
}
rm(arguments)

cat("\n   início: ", CONCURSO_INICIAL, "\n +recente: ", CONCURSO_MAIS_RECENTE, "\n\n> Preparando data frames ", sep="")

bolas <- 1:25   # sequência de numeração das bolas

# prepara a lista do número do concurso e do data frame das frequências,
# latências mais recentes, supremos das latências e valor 0-1 indicador das
# atipicidades dos números das bolas em cada concurso
lista <- vector('list', CONCURSO_MAIS_RECENTE-CONCURSO_INICIAL+1)
index=0
for (CONCURSO in CONCURSO_INICIAL:CONCURSO_MAIS_RECENTE) {
  cat('.')
  dat <- dbGetQuery(con, 'SELECT bola, COUNT(bola) AS frequencia, $NUMERO-MAX(concurso) AS latencia FROM bolas_sorteadas WHERE concurso <= $NUMERO GROUP BY bola', param=list('NUMERO'=CONCURSO))
  # completa o data frame se CONCURSO < 7 – que é o número serial do concurso no
  # qual historicamente todas as bolas foram sorteadas pela primeira vez –
  if (CONCURSO < 7) {
    for (bola in which( ! bolas %in% dat$bola )) {
      dat <- rbind(dat, c(bola, 0, CONCURSO))
    }
    dat <- dat[order(dat$bola),]
  }
  if (index > 0) {
    dat$supremo <- pmax(lista[[index]]$numeros$supremo, dat$latencia)
  } else {
    dat$supremo <- dat$latencia
  }
  dat$atipico <- (dat$frequencia < CONCURSO*15/25) & (dat$latencia >= 25/15)
  index <- index+1
  lista[[index]] <- list(concurso=CONCURSO, numeros=dat)
}
rm(dat)

cat(" finalizado.\n\n> Preparando parâmetros dos gráficos.\n\n")

# parâmetros compartilhados pelos diagramas

BAR_LABELS <- sprintf("%02d", bolas)    # labels das colunas
BAR_LABELS_CEX=1.375
BAR_LABELS_FONT=2
BAR_LABELS_COL="darkred"

STD_BAR_COLORS <- rep_len(c("gold", "orange"), 25)

BAR_BORDER='gray80' # cor das bordas das colunas
SPACE=0.25          # espaçamento entre colunas

RULE_COL="gray30"
TICKSIZE=-0.0125  # comprimento de "tick marks" secundários

ADJ=c(1, -0.5)  # ajuste para alinhar texto a direita e "acima"
ZADJ=c(0, 0)
TXT_CEX=0.9
TXT_FONT=2

HOT="tomato"    # cor para destacar linhas, textos, etc.
PALE="gray80"   # cor "discreta" das linhas de referência ordinárias
REF="purple"

BOX_AT=-0.35            # posição do "box & whiskers"
BOX_COL=c("mistyrose")  # cores de preenchimento dos "box & whiskers"

MATRIX <- matrix(c(1, 2), nrow=2, ncol=1); HEIGHTS=c(72, 28)  # layout "2x1"

MAR_FREQ <- c(2.5, 5.5, 1, 1)
MAR_LAT <- c(2.5, 5.5, 0, 1)

# menor valor de frequência no intervalo
minor <- (min(lista[[1]]$numeros$frequencia)%/%10)*10

# maior valor de frequência no intervalo
major <- (max(lista[[index]]$numeros$frequencia)%/%10+1)*10
yLIM_FREQ <- c(minor, major)

# configura escala das frequências com 10 marcas
increment <- (major-minor)%/%10
yFreq <- seq.int(from=minor, to=major, by=increment)
rFreq <- head(yFreq, -1)+increment/2

# maior valor das latências a partir do concurso inicial
maior <- max(lista[[index]]$numeros$supremo)

labLat <- yLat <- 0:maior
labLat[ yLat%%2 != 0 ] <- ""  # exclui rótulos dos valores ímpares

yLIM_LAT <- c(0, maior+.2)

ACC <- dbGetQuery(con, "SELECT concurso, ganhadores_15_numeros == 0 FROM
  concursos WHERE concurso BETWEEN $INICIAL AND $RECENTE",
  param=list("INICIAL"=CONCURSO_INICIAL, "RECENTE"=CONCURSO_MAIS_RECENTE))

dbDisconnect(con)

ACC_COLORS <- c("royalblue", "red")

# exclui conteúdo produzido anteriormente
system('rm -f video/quadros/*.png video/roteiro.txt')

# CAPA - o primeiro quadro da animação

png.filename <- 'quadros/capa.png'
png(
  filename=paste0('video/', png.filename), width=800, height=600,
  pointsize=11, family="Roboto"
)
par(mar=c(.5, .5, .5, .5), font=2)
plot(
  NULL, type="n", axes=F, xaxs="i", yaxs="i", xlab="", ylab="",
  xlim=c(0, 8), ylim=c(0, 6)
)
text(
  4, 4.25, "Evolução das Frequências e Latências",
  adj=c(.5, 0), cex=3.6, col="gray40"
)
text(4, 3.25, "Lotofácil", adj=c(.5, .5), cex=16, col="deepskyblue3")
text(
  4, 1.7, sprintf("Concurso %04d a %04d", CONCURSO_INICIAL,
    CONCURSO_MAIS_RECENTE), adj=c(.5, 0), cex=6, col="gray43"
)
text(
  4, .5, "Concepção \u5B89\u85E4 & J.Cicogna.",
  adj=c(.5, 0), cex=2.5, col="deepskyblue4"
)
dev.off()

# acessa arquivo da configuração da animação para ler as durações dos quadros
inp <- file("video/animacao.cfg", "r", blocking=FALSE)
durations <- readLines(inp)
close(inp)
extract <- function(nome){
  as.numeric(sub(".+=", "", durations[grep(nome, durations)]))
}
duration.first <- extract("first")
duration.last <- extract("last")
duration.default <- extract("default")
rm(extract, durations, inp)

# inicia o arquivo container do roteiro da animação utilizado pelo ffmpeg
roteiro <- file("video/roteiro.txt", "w", encoding="UTF-8")

# inicia o arquivo dos números seriais de concursos com premiação acumulada
acc <- file("video/acc.dat", "w", encoding="UTF-8")

cat("\n> Criando quadros da animação ")

index=0   # índice correspondente na lista

for (CONCURSO in CONCURSO_INICIAL:CONCURSO_MAIS_RECENTE) {

  cat(".")

  index <- index+1

  # cores para preenchimento "zebrado" das colunas, exceto as filtradas
  BAR_COLORS <- STD_BAR_COLORS
  BAR_COLORS[ lista[[index]]$numeros$atipico == T ] <- "darkorange2"

  png.filename <- sprintf('quadros/both-%04d.png', CONCURSO)

  cat("file '", png.filename, "'\nduration ", ifelse(CONCURSO>CONCURSO_INICIAL,
    ifelse(CONCURSO<CONCURSO_MAIS_RECENTE, duration.default, duration.last),
    duration.first), "\n", sep="", file=roteiro)

  # dispositivo de renderização: arquivo PNG container da imagem resultante
  png(
    filename=paste0("video/", png.filename), width=800, height=600,
    pointsize=9, family="Roboto Condensed"
  )

  layout(MATRIX, heights=HEIGHTS)  # layout "2x1"

  # -- DIAGRAMA DAS FREQUÊNCIAS

  par(
    mar=MAR_FREQ, las=1,
    font=2, cex.axis=1.4, font.axis=2, col.axis="#663300",  # labels do eixo Y
    cex.lab=1.625, font.lab=2, col.lab="dimgray"            # títulos laterais
  )

  bar <- barplot(
    lista[[index]]$numeros$frequencia,
    names.arg=BAR_LABELS, cex.names=BAR_LABELS_CEX,
    font.axis=BAR_LABELS_FONT, col.axis=BAR_LABELS_COL,
    border=BAR_BORDER, col=BAR_COLORS, space=SPACE,
    ylim=yLIM_FREQ,
    xpd=FALSE,            # inabilita renderização fora dos limites de Y
    yaxt='n'              # inabilita renderização default do eixo Y
  )

  title(ylab="Frequências", line=3.75)

  # renderiza o eixo Y conforme limites estabelecidos
  axis(side=2, at=yFreq, col=RULE_COL)
  # renderiza "tick marks" extras no eixo Y
  rug(rFreq, side=2, ticksize=TICKSIZE, lwd=1, col=RULE_COL)

  # renderiza texto e linha do valor esperado das frequências
  espera=CONCURSO*15/25
  abline(h=espera, col=REF, lty="dotted")
  X2=par("usr")[2]
  text(X2, espera, "esperança", adj=ADJ, cex=TXT_CEX, font=TXT_FONT, col=REF)
  # renderiza linhas de referência ordinárias evitando sobreposição
  abline(h=yFreq[yFreq > minor & abs(10*yFreq-CONCURSO) > 3], col=PALE, lty="dotted")

  # renderiza o "box & whiskers" entre o eixo Y e primeira coluna
  bp <- boxplot(
    lista[[index]]$numeros$frequencia,
    frame.plot=F, axes=F, add=T, at=BOX_AT,
    border=HOT, col=BOX_COL, yaxt='n', width=1, boxwex=1/3
  )

  # área hachurada do intervalo inter-quartílico
  rect(
    0, bp$stats[2], bar[25]+bar[1], bp$stats[4], col="#ff00cc28",
    border="transparent", density=18
  )

  # renderiza o número do concurso na margem direita alternando a cor do texto
  # conforme respectivo status de acumulação do prêmio principal
  text(X2, minor, sprintf("Lotofácil %04d", CONCURSO), srt=90, adj=ZADJ,
        cex=2.5, font=2, col=ACC_COLORS[ ACC[ACC$concurso == CONCURSO, 2]+1 ])

  if (ACC[ACC$concurso == CONCURSO, 2]) cat(CONCURSO, "\n", sep="", file=acc)

  # -- DIAGRAMA DAS LATÊNCIAS

  par(mar=MAR_LAT)

  bar <- barplot(
    lista[[index]]$numeros$latencia,
    names.arg=BAR_LABELS, cex.names=BAR_LABELS_CEX,
    font.axis=BAR_LABELS_FONT, col.axis=BAR_LABELS_COL,
    border=BAR_BORDER, col=BAR_COLORS, space=SPACE,
    ylim=yLIM_LAT, yaxt='n'
  )

  title(ylab="Latências", line=3.5)

  axis(side=2, at=yLat, col=RULE_COL, labels=labLat)

  # renderiza supremos das latências
  k <- (bar[2]-bar[1])/2-SPACE
  y <- lista[[index]]$numeros$supremo
  segments(bar-k, y, bar+k, y, col=c("dodgerblue", "green3"),
    lty="solid", lwd=4, ljoin='mitre')

  # renderiza texto e linha do valor esperado das latências
  espera=5/3
  abline(h=espera, col=REF, lty="dotted")
  text(X2, espera, "esperança", adj=ADJ, cex=TXT_CEX, font=TXT_FONT, col=REF)
  # renderiza linhas de referência ordinárias
  abline(h=yLat, col=PALE, lty="dotted")

  bp <- boxplot(
    lista[[index]]$numeros$latencia,
    frame.plot=F, axes=F, add=T, at=BOX_AT,
    border=HOT, col=BOX_COL, yaxt='n', width=1, boxwex=1/3
  )

  rect(
    0, bp$stats[2], bar[25]+bar[1], bp$stats[4], col="#ff00cc28",
    border="transparent", density=18
  )

  dev.off() # finaliza a renderização e fecha o arquivo

}

# as documented must to repeat the last one due to quirks
cat("file '", png.filename, "'\n", sep="", file=roteiro)
close(roteiro)

close(acc)

cat(" finalizado.\n\n")
