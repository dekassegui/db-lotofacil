#!/usr/bin/Rscript --no-init-file
#
# Diagrama de frequências e latências dos números sorteados na Lotofácil até o
# concurso mais recente - cujos dados estejam armazenados localmente - exibindo
# sumário de estatísticas de cada número, dos sorteios e do concurso.
#
library(RSQLite)
con <- dbConnect(SQLite(), "loto.sqlite")

# requisita o número do concurso mais recente, número de concursos acumulados
# e proporção de premiações ao longo do tempo
loto <- dbGetQuery(con, "WITH cte(m, n) AS (
  SELECT MAX(concurso), SUM(ganhadores_15_numeros>0) FROM concursos
) SELECT m AS concurso, m-MAX(concurso) AS acumulados, CAST(n as REAL)/m AS premiacao
  FROM cte, concursos WHERE ganhadores_15_numeros>0")

# requisita frequências e latências dos números no concurso mais recente
numeros <- dbGetQuery(con, "SELECT frequencia, latencia FROM info_bolas ORDER BY bola")

latencias <- vector("list", 25)

# query paramétrica para requisitar a sequência dos tempos de espera por
# NUMERO na série histórica dos concursos
rs <- dbSendQuery(con, "with cte(s) as (
  select group_concat(bolas >> ($NUMERO-1) & 1, '') from bolas_juntadas
), ones(n, p) as (
  select 1, instr(s, '1') from cte
  union all
  select n+1, p+instr(substr(s, p+1), '1') as m from cte, ones where m > p
) select p as espera from ones where n == 1
  union all
  select t.p-z.p from ones as t join ones as z on t.n == z.n+1")

# loop das requisições das sequências dos tempos de espera de cada NUMERO
for (n in 1:25) {
  dbBind(rs, list("NUMERO"=n))
  dat <- dbFetch(rs)
  latencias[[n]] <- dat$espera-1  # cálculo da latência
}
dbClearResult(rs)

# requisita os números sorteados no concurso anterior ao mais recente
anterior <- dbGetQuery(con, paste("SELECT bola FROM bolas_sorteadas WHERE concurso+1 ==", loto$concurso))

dbDisconnect(con)
rm(con, dat, rs)

# testa HØ: números ~ U(1, 25)
teste <- chisq.test(numeros$frequencia, correct=F)
x <- ifelse(teste$p.value >= .05, 1, 2)

# testa HØ: latências de qualquer número têm a mesma distribuição
teste <- kruskal.test(latencias)
y <- ifelse(teste$p.value >= .05, 1, 2)

numeros$maxLatencia <- sapply(latencias, max)
rm(latencias, teste)

numeros$corFundo <- "white"

five <- fivenum(numeros$frequencia)

cores <- colorRamp(c("#FFCC66", "orange1"), bias=1, space="rgb", interpolate="spline")
selection <- which(numeros$frequencia>five[4])
numeros[selection,]$corFundo <- rgb(cores((numeros[selection,]$frequencia-five[4])/(five[5]-five[4])), max=255)

cores <- colorRamp(c("yellow1", "gold1"), bias=.75, space="rgb", interpolate="spline")
selection <- which(numeros$frequencia>five[3] & numeros$frequencia<=five[4])
numeros[selection,]$corFundo <- rgb(cores((numeros[selection,]$frequencia-five[3])/(five[4]-five[3])), max=255)

cores <- colorRamp(c("#D0FFD0", "seagreen2"), bias=1, space="rgb", interpolate="spline")
selection <- which(numeros$frequencia>five[2] & numeros$frequencia<=five[3])
numeros[selection,]$corFundo <- rgb(cores((numeros[selection,]$frequencia-five[2])/(five[3]-five[2])), max=255)

cores <- colorRamp(c("#ACECFF", "skyblue1"), bias=1, space="rgb", interpolate="spline")
selection <- which(numeros$frequencia<=five[2])
numeros[selection,]$corFundo <- rgb(cores((numeros[selection,]$frequencia-five[1])/(five[2]-five[1])), max=255)

cores <- colorRampPalette(c("gray0", "gray10", "gray20", "gray80"))(25)
numeros$corFrente <- cores[rank(numeros$latencia, ties.method="last")]
# garante máxima tonalidade de cinza para números com mínima latência (=zero)
numeros[numeros$latencia == 0, "corFrente"] <- "black"

rm(cores, five, selection)

png(filename="img/dia.png", width=500, height=600, pointsize=10, family="Roboto Condensed")

par(mar=c(4.25, .75, 4.25, .75), font=2)

plot(NULL, type="n", axes=F, xaxs="i", yaxs="i", xlim=c(0, 5), ylim=c(0, 5), xlab="")

title(paste("Lotofácil", loto$concurso), adj=0, line=1.1875, cex.main=3.75)

mtext(
  c("concursos acumulados:", loto$acumulados,
    "premiação in tempore:", sprintf("%5.2f%%", 100*loto$premiacao)),
  side=3, at=c(4.46, 4.5), line=c(2.3, 2.3, 1, 1), adj=c(1, 0),
  cex=1.26, col=c("gray20", "sienna"), family="Roboto"
)

dat <- matrix(c("\uF00C", "\uF00D", "dodgerblue", "red"), ncol=2, byrow=T)
mtext(
  c("números i.i.d. U\u276A1, 25\u276B", dat[1,x],
    "latências i.i.d. Geom\u276A0.6\u276B", dat[1,y]),
  side=1, at=c(1.67, 1.71), line=c(1, 1.2, 2.4, 2.6), adj=c(1, 0),
  cex=c(1.26, 1.75), col=c("gray20", dat[2,x], "gray20", dat[2,y]),
  family="Roboto"
)
rm(dat)

# LEGENDA DAS QUADRÍCULAS

rect(2.82, -0.06, 4.88, -0.46, xpd=T, col="#FFFFA0", border=NA) # background
mtext(
  c("frequência", "Atípico\u2215Reincidente", "latência", "latência recorde"),
  side=1, at=c(2.88, 4.82), line=c(1, 1, 2.4, 2.4), adj=c(0, 1), cex=1.26,
  col=c("darkred", "black", "violetred", "firebrick"), family="Roboto"
)

# ESCALA DE CORES DAS QUADRÍCULAS

mtext(
  rep("\u25A0", 4), side=1, at=5, line=seq(from=.4, by=.81, length.out=4),
  adj=1, cex=1.1, col=c("orange1", "gold2", "#66CC00", "#33C9FF")
)

for (n in 1:25) {
  x <- (n-1) %% 5
  y <- (n-1) %/% 5
  attach(numeros[n,])
  # renderiza a quadricula com cor em função da frequência
  rect(x, 4-y, x+1, 5-y, col=corFundo, border="white", lwd=1.5)
  # renderiza o número com cor em função da latência em relevo
  text(
    c(x+.51, x+.5), c(4.49-y, 4.5-y), sprintf("%02d", n),
    adj=c(.5, .5), cex=4, col=c("white", corFrente)
  )
  # frequência histórica
  text(x+.1, 4.9-y, frequencia, adj=c(0, 1), cex=1.5, col="darkred")
  # checa se frequência abaixo do esperado e latência acima do esperado
  if (5/3*frequencia < loto$concurso & latencia >= 5/3) {
    text(x+.9, 4.9-y, "A", adj=c(1, 1), cex=1.25, col="black")
  } else if (latencia == 0) {
    # renderiza borda extra para evidenciar número recém sorteado
    rect(
      x+.025, 4.025-y, x+.975, 4.975-y, col="transparent", border="black", lwd=2
    )
    # checa se número é reincidente -- sorteado no concurso anterior
    if (n %in% anterior$bola) {
      text(x+.9, 4.9-y, "R", adj=c(1, 1), cex=1.25, col="black")
    }
  }
  # latência imediata
  text(x+.1, 4.1-y, latencia, adj=c(0, 0), cex=1.5, col="violetred")
  # máxima latência histórica
  text(x+.9, 4.1-y, maxLatencia, adj=c(1, 0), cex=1.5, col="firebrick")
  detach(numeros[n,])
}

dev.off()
