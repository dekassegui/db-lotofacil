# db-lotofacil

Criação/manutenção do DB da Lotofácil, com dados baixados do website da
Caixa Econômica Federal - Loterias.

Este é um projeto -- concebido em plena pandemia -- irmão do <a
href="https://github.com/dekassegui/db-megasena">db-megasena</a> que
contempla a mudança da oferta de dados públicos da série temporal dos
concursos em 07-05-2021.

** Uso corriqueiro

1. Geração dos diagramas das estatísticas do concurso mais recente:

<code>prompt/ <strong>R/dia.R && R/plot-both.R</strong></code>

2. Geração de animação de série _arbitrária_ de diagramas de frequências e
latências dos números sorteados nos concursos:

<code>prompt/ <strong>R/anima.R 2122 && scripts/anima.sh</strong></code>

   onde 2122 foi arbitrariamente escolhido e usa-se amplamente o software
   **ffmpeg** para a dita geração.

Isto não é um sistema de apostas e não advogamos pela Caixa, mas louvamos a
qualidade dos concursos do ponto de vista matemático/estatístico.

Faça bom uso e boa sorte.

