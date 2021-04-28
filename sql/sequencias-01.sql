/*
  Montagem da tabela dos comprimentos de sequências de números consecutivos nos
  concursos da lotofácil na ordem de ocorrência na série histórica de concursos
  tal que cada linha contém o comprimento da sequência identificada seguido do
  respectivo número serial do concurso ao qual pertence.
*/
DROP TABLE IF EXISTS sequencias;
CREATE TABLE sequencias (len integer, concurso integer);
INSERT INTO sequencias
  WITH RECURSIVE box (id, len) AS (
    WITH RECURSIVE bag (s) AS ( -- concatenação das bitmasks
      SELECT group_concat(mask, '0') || '0' AS s FROM (
        SELECT ( -- montagem de bitmasks da esquerda para direita
          WITH RECURSIVE bits (n, r) AS (
            VALUES (-1, '')
            UNION ALL
            SELECT n+1, r || (bolas >> n+1 & 1) FROM bits WHERE n < 25
          ) SELECT r FROM bits WHERE n == 24
        ) AS mask
        FROM bolas_juntadas
      )
    ), ones (id, p) AS ( -- pesquisa das posições iniciais das sequências
      SELECT 1, instr(s, '1') FROM bag
      UNION ALL
      SELECT id+1, p+instr(substr(s, p+1), '01')+1 AS m FROM bag, ones
      WHERE m-1 > p
    ) SELECT id, instr(substr(s, p), '0')-1 AS len FROM bag, ones
  ), list (len, soma) AS ( -- identificação do número serial dos concursos
    SELECT len, sum(len) OVER ( ORDER BY id ) FROM box
  ) SELECT len, (soma-1)/15+1 AS concurso FROM list;
    /* -- para versões do SQLite sem implementação de window functions
      list (len, soma, n) AS ( -- identificação do número serial do concurso
        SELECT 0, -1, 0
        UNION ALL
        SELECT box.len, soma+box.len, n+1 FROM list, box WHERE box.id == n+1
      ) SELECT len, soma/15+1 AS concurso FROM list WHERE n;
    */

DROP VIEW IF EXISTS seq;
CREATE TEMP VIEW seq AS
  SELECT concurso, cast(count(len) AS int) AS n, group_concat(len, ' ') AS m
  FROM sequencias GROUP BY concurso;
