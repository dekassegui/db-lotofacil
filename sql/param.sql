/**
 * Esquema para viabilizar análises de sequências de resultados lógicos sob
 * o ponto de vista dos processos estocásticos, com atenção especial para o
 * Processo de Bernoulli, para o qual há consulta ao "tempo de espera por 1º
 * sucesso" além de outras.
*/
BEGIN TRANSACTION;

/**
 * Tabela de parâmetros utilizados na consulta "esperas" que acessa o registro
 * incumbente – o único com valor da coluna "status" igual a "1".
*/
CREATE TABLE IF NOT EXISTS param (
  s       TEXT NOT NULL                 -- string 0-1 representando alguma
           CHECK(trim(s) <> ""          -- sequência de valores lógicos
            AND NOT s GLOB "*[^01]*"),

  comentario  TEXT DEFAULT NULL,        -- comentário arbitrário

  status  BOOLEAN NOT NULL DEFAULT 0    -- indicador para acesso exclusivo
           CHECK(status GLOB "[01]")    -- ao registro quando igual a "1"
);

-- se registro foi inserido como incumbente então será o único
CREATE TRIGGER IF NOT EXISTS on_param_insert AFTER INSERT ON param
WHEN new.status == 1
BEGIN
  UPDATE param SET status=0 WHERE ROWID <> new.ROWID;
END;

-- se registro foi atualizado como incumbente então será o único
CREATE TRIGGER IF NOT EXISTS on_param_update AFTER UPDATE OF status ON param
WHEN old.status == 0 AND new.status == 1
BEGIN
  UPDATE param SET status=0 WHERE ROWID <> new.ROWID;
END;

/**
 * Acessa o único registro incumbente da tabela "param", para sequencialmente
 * alistar as posições de "1" em "s" e então calcula as diferenças entre cada
 * posição e a anterior exceto a primeira, cujo valor é a própria posição –
 * o que equivale a medir os valores de tempo de espera pelo primeiro sucesso
 * numa sequência de variáveis aleatórias iid Bernoulli(p) – tabulando:
 *
 *   ndx <- número de ordem da medição
 *   fim <- posição do sucesso na sequência
 *   len <- tempo de espera pelo 1º sucesso
*/
CREATE VIEW IF NOT EXISTS esperas AS
  WITH par (s) AS (
    SELECT s FROM param WHERE status
  ), ones (n, p) AS (
    SELECT 1, instr(s, "1") FROM par
    UNION ALL
    SELECT n+1, p+instr(substr(s, p+1), "1") AS m FROM par, ones WHERE m > p
  ) SELECT n AS ndx, p AS fim, p AS len FROM ones WHERE n == 1
    UNION ALL
    SELECT a.n, a.p, (a.p - b.p) FROM ones AS a JOIN ones AS b ON a.n == b.n+1;

-- tabela dos valores de tempo de espera pelo 2º sucesso
CREATE VIEW IF NOT EXISTS duo AS
  WITH uno AS (
    SELECT * FROM esperas
  ) SELECT a.ndx/2 AS ndx, a.fim, (
        SELECT SUM(len) FROM uno WHERE ndx BETWEEN a.ndx-2+1 AND a.ndx
      ) AS len
    FROM (SELECT * FROM uno WHERE ndx%2 == 0) AS a;

-- tabela dos valores de tempo de espera pelo 3º sucesso
CREATE VIEW IF NOT EXISTS trio AS
  WITH uno AS (
    SELECT * FROM esperas
  ) SELECT a.ndx/3 AS ndx, a.fim, (
        SELECT SUM(len) FROM uno WHERE ndx BETWEEN a.ndx-3+1 AND a.ndx
      ) AS len
    FROM (SELECT * FROM uno WHERE ndx%3 == 0) AS a;

/**
 * Acessa o único registro incumbente da tabela "param", para sequencialmente
 * alistar as posições iniciais e comprimentos de subsequências somente de "1"
 * em "s" – o que equivale a identificar os períodos de sucessos consecutivos
 * numa sequência de resultados lógicos – tabulando:
 *
 *    ndx: número de ordem da identificação
 *    ini: posição inicial da subsequência  – número serial do concurso inicial
 *    len: comprimento da subsequência      – número de concursos consecutivos
*/
CREATE VIEW IF NOT EXISTS incidencias AS
  WITH RECURSIVE par (s) AS (
    SELECT s FROM param WHERE status
  ), ones (n, i) AS (
    SELECT 1, INSTR(s, "1") FROM par  -- posição inicial da primeira
    UNION ALL
    SELECT n+1, i+INSTR(SUBSTR(s, i+1), "01")+1 AS k  -- posição inicial da
      FROM par, ones WHERE k > i+1                     -- segunda em diante
  ) SELECT n AS ndx, i AS ini,
        INSTR(SUBSTR(s, i), "0")-1 AS len
      FROM (
        SELECT s||"0" AS s  -- apêndice "0" é artifício p/calcular comprimento
          FROM par          -- de possível subsequência na extremidade direita
      ), ones;

CREATE VIEW IF NOT EXISTS combo AS
  SELECT i.ini, i.len, e.fim, e.len AS espera
  FROM esperas AS e LEFT JOIN incidencias AS i ON e.fim == i.ini+i.len-1;

END TRANSACTION;

/*
  -- Exemplos de preenchimento e atualização da tabela "param"

  INSERT INTO param (s, comentario, status) VALUES ("0001101011011" "teste", 1);

  UPDATE param SET status=0 WHERE comentario IS "teste";

  INSERT INTO param (comentario, s)
    SELECT "premiação principal",
      group_concat(ganhadores_15_numeros>0, "") FROM concursos;

  UPDATE param SET status=1 WHERE comentario GLOB "premia??o*";

  INSERT INTO param (status, comentario, s)
    SELECT 0, "incidência da bola 25",
      group_concat(bolas>>(25-1)&1, "") FROM bolas_juntadas;

  UPDATE param SET status=1 WHERE rowid == 2;
*/
