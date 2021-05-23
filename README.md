# db-lotofacil

Scripts para criação, atualização e consultas a DB dos concursos da **Lotofácil** com utilização do <a href="http://www.sqlite.org" title="clique para acessar o website do SQLite">SQLite</a> mais extensões carregáveis, viabilizando analises estatísticas via <a href="http://www.r-project.org/" title="clique para acessar o website do R Statistical Computing...">R Statistical Computing Environment</a> ou similar.

Este é um projeto – <em>concebido em plena pandemia</em> – irmão do <a href="https://github.com/dekassegui/db-megasena">db-megasena</a> que contempla também a mudança da oferta de dados públicos da série temporal dos concursos em 07 de maio de 2021.

Isto não é um sistema de apostas e não advogamos pela Caixa, mas louvamos a qualidade dos concursos do ponto de vista matemático/estatístico.

## Dependências

Todas as libs e aplicativos usados estão disponíveis nos repositórios Linux:

> <code>prompt/ sudo apt-get install <strong>sqlite3 sqlite3-pcre xsltproc tidy wget libxml2-utils r-base r-cran-rsqlite r-cran-vcd r-cran-rcmdrmisc ffmpeg ffprobe ffplay</strong></code>

## Uso Corriqueiro

  1. Atualização do db com dados baixados do website da <a href="http://loterias.caixa.gov.br/wps/portal/loterias/landing/lotofacil" title="link de download disponível após resultado do concurso mais recente">Caixa Econômica Federal > Loterias > Lotofácil</a>:

  > <code>prompt/ <strong>./atualiza-db.sh</strong></code>

  2. Geração dos diagramas estatísticos do concurso mais recente:
  ![diagramas](https://github.com/dekassegui/db-lotofacil/blob/master/img/diagramas-2235.png "diagramas")

  > <code>prompt/ <strong>R/dia.R && R/plot-both.R</strong></code>

  3. Geração de animação de sequências de diagramas estatísticos dos concursos:

  > <code>prompt/ <strong>R/anima.R [<em>número de concurso</em>] && scripts/anima.sh</strong></code>
