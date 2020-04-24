#!/usr/bin/Rscript --no-init-file
#
# Script gerador da imagem do diagrama das frequências e do diagrama das
# latências dos números sorteados até o concurso mais recente disponível,
# visualmente homogêneos e alinhados verticalmente.

library(RSQLite)  # r-cran-sqlite <-- Database Interface R driver for SQLite

con <- dbConnect(SQLite(), dbname='loto.sqlite')

# requisita o número serial do concurso mais recente, frequências dos números,
# das bolas sorteadas na série histórica, suas latências mais recentes e valor
# 0-1 indicador da atipicidade de cada número
query='SELECT concurso, frequencia, latencia, atipico FROM info_bolas'
numeros <- dbGetQuery(con, query)
dbDisconnect(con)

CONCURSO <- numeros[1, c('concurso')]

# parâmetros compartilhados pelos diagramas

BAR_LABELS <- c(sprintf("%02d", 1:25))  # labels das colunas (ou barras)
BAR_LABELS_CEX=1.375
BAR_LABELS_FONT=2
BAR_LABELS_COL="darkred"

# cores para preenchimento "zebrado" das colunas, exceto as filtradas
BAR_COLORS <- rep_len(c("gold", "orange"), 25)
BAR_COLORS[ numeros$atipico == 1 ]="darkorange2"

BAR_BORDER='gray80' # cor das bordas das colunas
SPACE=0.25          # espaçamento entre colunas

RULE_COL="gray30"
TICKSIZE=-0.0175  # comprimento de "tick marks" secundários

ADJ=c(1, -0.5)  # ajuste para alinhar texto a direita e "acima"
TXT_CEX=0.9
TXT_FONT=2

HOT="tomato"    # cor para destacar linhas, textos, etc.
PALE="gray80"   # cor "discreta" das linhas de referência ordinárias
REF="purple"

BOX_AT=-0.35            # posição do "box & whiskers"
BOX_COL=c("mistyrose")  # cores de preenchimento dos "box & whiskers"

# dispositivo de renderização: arquivo PNG container da imagem resultante
png(
  filename=sprintf('img/both-%d.png', CONCURSO),
  width=800, height=600, pointsize=9, family="Roboto Condensed"
)

par(
  las=1, font=2,
  cex.axis=1.4, font.axis=2, col.axis="#663300",  # labels do eixo Y
  cex.lab=1.625, font.lab=2, col.lab="dimgray"    # títulos laterais
)

minor=(min(numeros$frequencia)%/%10-1)*10 # limite inferior do eixo Y
major=(max(numeros$frequencia)%/%10+1)*10 # limite superior do eixo Y

# layout "2x1" com alturas das áreas proporcionais à amplitude das frequências
layout(
  matrix(c(1, 2), nrow=2, ncol=1),
  heights=c(major-minor, (major-minor)/ifelse(max(numeros$latencia)>9, 2, 5))
)

# -- DIAGRAMA DAS FREQUÊNCIAS

par(mar=c(2.5, 5.5, 1, 1))

bar <- barplot(
  numeros$frequencia,
  names.arg=BAR_LABELS, cex.names=BAR_LABELS_CEX,
  font.axis=BAR_LABELS_FONT, col.axis=BAR_LABELS_COL,
  border=BAR_BORDER, col=BAR_COLORS, space=SPACE,
  ylim=c(minor, major),
  xpd=FALSE,            # inabilita renderização fora dos limites de Y
  yaxt='n'              # inabilita renderização default do eixo Y
)

title(ylab="Frequências", line=3.75)

yLab=seq.int(from=minor, to=major, by=10)
# renderiza o eixo Y conforme limites estabelecidos
axis(side=2, at=yLab, col=RULE_COL)
# renderiza "tick marks" extras no eixo Y
rug(head(yLab, -1)+5, side=2, ticksize=TICKSIZE, lwd=1, col=RULE_COL)

# renderiza texto e linha do valor esperado das frequências
espera=CONCURSO*15/25
abline(h=espera, col=REF, lty="dotted")
X2=par("usr")[2]
text(X2, espera, "esperança", adj=ADJ, cex=TXT_CEX, font=TXT_FONT, col=REF)
# renderiza linhas de referência ordinárias evitando sobreposição
abline(h=yLab[yLab > minor & abs(10*yLab-CONCURSO) > 3], col=PALE, lty="dotted")

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

# renderiza o número do concurso mais recente na margem direita
text(
  X2, minor, paste("Lotofácil", CONCURSO),
  srt=90, adj=c(0, 0), cex=2.5, font=2, col=par("col.lab")
)

# -- DIAGRAMA DAS LATÊNCIAS

par(mar=c(2.5, 5.5, 0, 1))

major=max(3, max(numeros$latencia)) # limite superior do eixo Y

bar <- barplot(
  numeros$latencia,
  names.arg=BAR_LABELS, cex.names=BAR_LABELS_CEX,
  font.axis=BAR_LABELS_FONT, col.axis=BAR_LABELS_COL,
  border=BAR_BORDER, col=BAR_COLORS, space=SPACE,
  ylim=c(0, major+.2), yaxt='n'
)

title(ylab="Latências", line=3.5)

yLab=seq.int(from=0, to=major, by=ifelse(major>4, 2, 1))
axis(side=2, at=yLab, col=RULE_COL)
if (major>4) {
  rug(side=2, seq.int(1, max(yLab), 2), ticksize=-.05, lwd=.85, col=RULE_COL)
}

# renderiza texto e linha do valor esperado das latências
espera=5/3
abline(h=espera, col=REF, lty="dotted")
text(X2, espera, "esperança", adj=ADJ, cex=TXT_CEX, font=TXT_FONT, col=REF)
# renderiza linhas de referência ordinárias
abline(h=yLab, col=PALE, lty="dotted")

bp <- boxplot(
  numeros$latencia, frame.plot=F, axes=F, add=T, at=BOX_AT,
  border=HOT, col=BOX_COL, yaxt='n', width=1, boxwex=1/3
)

rect(
  0, bp$stats[2], bar[25]+bar[1], bp$stats[4], col="#ff00cc28",
  border="transparent", density=18
)

dev.off() # finaliza a renderização e fecha o arquivo
