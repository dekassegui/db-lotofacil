# db-lotofacil

Criação/manutenção do DB da Lotofácil, com dados baixados do website da <a href="http://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil" title="link de download disponível após resultado do concurso mais recente">Caixa Econômica Federal > Loterias > Lotofácil</a>.

Este é um projeto – <em>concebido em plena pandemia</em> – irmão do <a href="https://github.com/dekassegui/db-megasena">db-megasena</a> que contempla a mudança da oferta de dados públicos da série temporal dos concursos em 07 de maio de 2021.

Isto não é um sistema de apostas e não advogamos pela Caixa, mas louvamos a qualidade dos concursos do ponto de vista matemático/estatístico.

## Dependências

Instale as libs e aplicativos (<i>disponíveis nos repositórios Linux</i>):

> <code>prompt/ sudo apt-get install <strong>sqlite3 sqlite3-pcre xsltproc tidy wget libxml2 r-base r-cran-rsqlite r-cran-vcd r-cran-rcmdrmisc ffmpeg ffplay</strong></code>

## Uso corriqueiro

1. Atualização do db:

> <code>prompt/ <strong>./atualiza-db.sh</strong></code>

2. Geração dos diagramas estatísticos do concurso mais recente:

> <code>prompt/ <strong>R/dia.R && R/plot-both.R</strong></code>

3. Geração de animação da evolução dinâmica de estatísticas dos concursos:

> <code>prompt/ <strong>R/anima.R [<em>número de concurso</em>] && scripts/anima.sh</strong></code>
