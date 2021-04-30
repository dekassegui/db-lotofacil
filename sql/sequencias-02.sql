-- carrega extensão do SQLite implementando Perl Regular Expressions
.load "/usr/lib/sqlite3/pcre.so"

-- contagem de concursos que contém sequências de números sorteados consecutivos
-- com comprimento 1 até 15, identificando primeiras ocorrências nas respectivas
-- bitmasks via expressões regulares que ignoram subsequências
WITH RECURSIVE CTE (fmt) AS (
  SELECT "(?# to search the first occurrence)[^1]1{%d}[^1]"
), REX (n, expression) AS ( -- montagem única das 15 expressões regulares
  SELECT 1, printf(fmt, 1) FROM CTE
  UNION ALL
  SELECT n+1, printf(fmt, n+1) FROM CTE, REX WHERE n < 15
), LST (width) AS ( -- identificação das sequências
  SELECT n FROM REX, bitmasks WHERE mask regexp expression
) SELECT width, count(1) AS times FROM LST GROUP BY width;
