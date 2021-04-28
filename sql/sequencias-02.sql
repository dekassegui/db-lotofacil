-- carrega extensão do SQLite implementando Perl Regular Expressions
.load "/usr/lib/sqlite3/pcre.so"

-- contagem de concursos que contém sequências de números sorteados consecutivos
-- com comprimento 1 até 15, unicamente identificadas nas respectivas bitmasks
-- via expressões regulares que ignoram subsequências
WITH RECURSIVE CTE AS (
  SELECT "^1{%d}0|01{%d}0|01{%d}$" AS fmt
), REX AS ( -- montagem das expressões regulares
  SELECT 1 AS n, printf(fmt, 1, 1, 1) AS expression FROM CTE
  UNION ALL
  SELECT n+1, printf(fmt, n+1, n+1, n+1) FROM CTE, REX WHERE n < 15
), LST AS ( -- identificação das sequências
  SELECT n AS width FROM REX, bitmasks WHERE mask regexp expression
) SELECT width, count(1) AS times FROM LST GROUP BY width;
