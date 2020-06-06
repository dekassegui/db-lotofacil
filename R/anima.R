#!/usr/bin/Rscript --no-init-file
#
# Script gerador de imagens do diagrama das frequências e latências dos números
# sorteados em cada um dos 156 concursos mais recentes, as quais serão quadros
# de animação via ffmpeg ou aplicativo similar.

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), dbname='loto.sqlite')

CONCURSO_MAIS_RECENTE <- dbGetQuery(con, 'SELECT MAX(concurso) FROM concursos')[1, 1]

CONCURSO_INICIAL <- CONCURSO_MAIS_RECENTE-156+1

# requisita número da bola, suas frequências, latências mais recentes e
# valor 0-1 indicador de suas atipicidades até o concurso $NUMERO
query <- "SELECT bola, frequencia, latencia, (frequencia < u AND latencia >= v) AS atipico
FROM (
  SELECT bola, count(bola) AS frequencia, ($NUMERO-max(concurso)) AS latencia, ($NUMERO*15.0/25) AS u, (25.0/15) AS v
  FROM bolas_sorteadas WHERE concurso <= $NUMERO
  GROUP BY bola
)"

# parâmetros compartilhados pelos diagramas

BAR_LABELS <- c(sprintf("%02d", 1:25))  # labels das colunas (ou barras)
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

# menor valor de frequência a partir do concurso inicial
numeros <- dbGetQuery(con, query, param=list('NUMERO'=CONCURSO_INICIAL))
minor <- (min(numeros$frequencia)%/%10)*10 # limite inferior do eixo Y

# maior valor de frequência a partir do concurso inicial
numeros <- dbGetQuery(con, query, param=list('NUMERO'=CONCURSO_MAIS_RECENTE))
major <- (max(numeros$frequencia)%/%10+1)*10 # limite superior do eixo Y

yFreq <- seq.int(from=minor, to=major, by=20)

rFreq <- head(yFreq, -1)+10

yLIM_FREQ <- c(minor, major)

# maior valor das latências a partir do concurso inicial
maior <- max(sapply(CONCURSO_INICIAL:CONCURSO_MAIS_RECENTE,
function(CONCURSO) {
  dbGetQuery(con, 'SELECT MAX(latencia) FROM (SELECT $NUMERO-MAX(concurso) AS latencia FROM bolas_sorteadas WHERE concurso <= $NUMERO GROUP BY bola)', param=list('NUMERO'=CONCURSO))[1, 1]
}))

labLat <- yLat <- 0:maior; labLat[yLat%%2 != 0] <- ""

yLIM_LAT <- c(0, maior+.2)

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
  4, 1.7, paste("Concurso", CONCURSO_INICIAL, "a", CONCURSO_MAIS_RECENTE),
  adj=c(.5, 0), cex=6, col="gray43"
)
text(
  4, .5, "Concepção \u5B89\u85E4 & J.Cicogna.",
  adj=c(.5, 0), cex=2.5, col="deepskyblue4"
)
dev.off()

# inicia o arquivo container do roteiro da animação utilizado pelo ffmpeg
out <- file("video/roteiro.txt", "w", encoding="UTF-8")
cat("file ", png.filename, "\nduration 3\n", sep="'", file=out)

# durações dos quadros da animação exceto a capa
CONCURSO <- CONCURSO_MAIS_RECENTE-CONCURSO_INICIAL+1
duration <- rep.int(signif(17/64, digits=4), CONCURSO)  # valor default
duration[1] <- 1; duration[CONCURSO] <- 4

cat("\nProcessando")

for (CONCURSO in CONCURSO_INICIAL:CONCURSO_MAIS_RECENTE) {

  cat(".")

  numeros <- dbGetQuery(con, query, param=list('NUMERO'=CONCURSO))

  # cores para preenchimento "zebrado" das colunas, exceto as filtradas
  BAR_COLORS <- STD_BAR_COLORS
  BAR_COLORS[ numeros$atipico == 1 ] <- "darkorange2"

  png.filename <- sprintf('quadros/both-%04d.png', CONCURSO)

  cat("file ", png.filename, paste0("\nduration ",
    duration[CONCURSO-CONCURSO_INICIAL+1], "\n"), sep="'", file=out)

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
    numeros$frequencia,
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
    numeros$frequencia, frame.plot=F, axes=F, add=T, at=BOX_AT,
    border=HOT, col=BOX_COL, yaxt='n', width=1, boxwex=1/3
  )

  # área hachurada do intervalo inter-quartílico
  rect(
    0, bp$stats[2], bar[25]+bar[1], bp$stats[4], col="#ff00cc28",
    border="transparent", density=18
  )

  # renderiza o número do concurso na margem direita
  text(
    X2, minor, paste("Lotofácil", CONCURSO),
    srt=90, adj=ZADJ, cex=2.5, font=2, col=par("col.lab")
  )

  # -- DIAGRAMA DAS LATÊNCIAS

  par(mar=MAR_LAT)

  bar <- barplot(
    numeros$latencia,
    names.arg=BAR_LABELS, cex.names=BAR_LABELS_CEX,
    font.axis=BAR_LABELS_FONT, col.axis=BAR_LABELS_COL,
    border=BAR_BORDER, col=BAR_COLORS, space=SPACE,
    ylim=yLIM_LAT, yaxt='n'
  )

  title(ylab="Latências", line=3.5)

  axis(side=2, at=yLat, col=RULE_COL, labels=labLat)

  # renderiza texto e linha do valor esperado das latências
  espera=5/3
  abline(h=espera, col=REF, lty="dotted")
  text(X2, espera, "esperança", adj=ADJ, cex=TXT_CEX, font=TXT_FONT, col=REF)
  # renderiza linhas de referência ordinárias
  abline(h=yLat, col=PALE, lty="dotted")

  bp <- boxplot(
    numeros$latencia, frame.plot=F, axes=F, add=T, at=BOX_AT,
    border=HOT, col=BOX_COL, yaxt='n', width=1, boxwex=1/3
  )

  rect(
    0, bp$stats[2], bar[25]+bar[1], bp$stats[4], col="#ff00cc28",
    border="transparent", density=18
  )

  dev.off() # finaliza a renderização e fecha o arquivo

}

# as documented must to repeat the last one due to quirks
cat("file ", png.filename, "\n", sep="'", file=out)
close(out)

cat("finalizado.\n\n")

dbDisconnect(con)
