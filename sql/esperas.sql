DROP TABLE IF EXISTS param;
DROP VIEW IF EXISTS esperas;
DROP VIEW IF EXISTS duo;
DROP VIEW IF EXISTS trio;

BEGIN TRANSACTION;

/**
   Tabela de parâmetros utilizados na consulta "esperas" que acessa o registro
   incumbente -- o único com valor da coluna "status" igual a "1".
*/
CREATE TABLE param (
  s       TEXT NOT NULL                 -- string 0-1 representando alguma
           CHECK(trim(s) <> ""          -- sequência de valores lógicos
            AND NOT s GLOB "*[^01]*"),

  comentario  TEXT DEFAULT NULL,        -- comentário arbitrário

  status  BOOLEAN NOT NULL DEFAULT 0    -- indicador para acesso exclusivo
           CHECK(status GLOB "[01]")    -- ao registro quando igual a "1"
);

-- se registro foi inserido como incumbente então será o único
CREATE TRIGGER on_param_insert AFTER INSERT ON param
WHEN new.status == 1
BEGIN
  UPDATE param SET status=0 WHERE ROWID <> new.ROWID;
END;

-- se registro foi atualizado como incumbente então será o único
CREATE TRIGGER on_param_update AFTER UPDATE OF status ON param
WHEN old.status == 0 AND new.status == 1
BEGIN
  UPDATE param SET status=0 WHERE ROWID <> new.ROWID;
END;

/**
   Acessa o único registro incumbente da tabela "param", para sequencialmente
   alistar as posições de "1" em "s" e então calcula as diferenças entre cada
   posição e a anterior exceto a primeira, cujo valor é a própria posição --
   o que equivale a medir os valores de tempo de espera pelo primeiro sucesso
   numa sequência de variáveis aleatórias iid Bernoulli(p) -- tabulando:

     ndx <- número de ordem da medição
     fim <- posição do sucesso na sequência
     len <- tempo de espera pelo 1º sucesso
*/
CREATE VIEW esperas AS
  WITH par (s) AS (
    SELECT s FROM param WHERE status
  ), ones (n, p) AS (
    SELECT 1, instr(s, "1") FROM par
    UNION ALL
    SELECT n+1, p+instr(substr(s, p+1), "1") AS m FROM par, ones WHERE m > p
  ) SELECT n AS ndx, p AS fim, p AS len FROM ones WHERE n == 1
    UNION ALL
    SELECT a.n, a.p, (a.p - b.p) FROM ones AS a JOIN ones AS b ON a.n == b.n+1;

-- tabela dos valores de tempo de espera até 2º sucesso
create view duo as
  with uno as (
    select * from esperas
  ) select a.ndx/2 as ndx, a.fim, (
        select sum(len) from uno where ndx between a.ndx-2+1 and a.ndx
      ) as len
    from (select * from uno where ndx%2 == 0) as a;

-- tabela dos valores de tempo de espera até 3º sucesso
create view trio as
  with uno as (
    select * from esperas
  ) select a.ndx/3 as ndx, a.fim, (
        select sum(len) from uno where ndx between a.ndx-3+1 and a.ndx
      ) as len
    from (select * from uno where ndx%3 == 0) as a;

END TRANSACTION;

INSERT INTO param (comentario, s)
  SELECT "premiação principal",
    group_concat(ganhadores_15_numeros>0, "") FROM concursos;

INSERT INTO param (status, comentario, s)
  SELECT 1, "incidência da bola 25",
    group_concat(bolas>>(25-1)&1, "") FROM bolas_juntadas;
