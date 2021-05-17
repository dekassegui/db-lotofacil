-- carrega extensão do SQLite implementando Perl Regular Expressions
.load "/usr/lib/sqlite3/pcre.so"

-- contagem de concursos agrupados pelos comprimentos de sequências de números
-- sorteados consecutivos – de 1 a 15 números – cujas primeiras ocorrências são
-- identificadas via expressões regulares que ignoram subsequências, aplicadas
-- aos bitmasks dos números sorteados nos respectivos concursos
WITH RECURSIVE REX (width, expression) AS (
  SELECT 1, "[^1]1[^1]"
  UNION ALL
  SELECT width+1, "[^1]1{" || (width+1) || "}[^1]" FROM REX WHERE width < 15
) SELECT width, count(1) AS times FROM (
    SELECT width FROM REX, bitmasks WHERE mask regexp expression
  ) GROUP BY width;
