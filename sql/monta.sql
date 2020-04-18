-- Cria ou recria todas as tabelas, views, índices e triggers.
BEGIN TRANSACTION;
PRAGMA legacy_file_format = ON;

DROP TABLE IF EXISTS concursos;
CREATE TABLE concursos (
  -- tabela obtida por conversão de documento HTML que contém
  -- a série temporal completa dos concursos da loto fácil
  concurso                  INTEGER PRIMARY KEY,
  data_sorteio              DATETIME NOT NULL ON CONFLICT ABORT, -- yyyy-mm-dd
  bola1                     INTEGER CHECK (bola1 BETWEEN 1 AND 25),
  bola2                     INTEGER CHECK (bola2 BETWEEN 1 AND 25),
  bola3                     INTEGER CHECK (bola3 BETWEEN 1 AND 25),
  bola4                     INTEGER CHECK (bola4 BETWEEN 1 AND 25),
  bola5                     INTEGER CHECK (bola5 BETWEEN 1 AND 25),
  bola6                     INTEGER CHECK (bola6 BETWEEN 1 AND 25),
  bola7                     INTEGER CHECK (bola7 BETWEEN 1 AND 25),
  bola8                     INTEGER CHECK (bola8 BETWEEN 1 AND 25),
  bola9                     INTEGER CHECK (bola9 BETWEEN 1 AND 25),
  bola10                    INTEGER CHECK (bola10 BETWEEN 1 AND 25),
  bola11                    INTEGER CHECK (bola11 BETWEEN 1 AND 25),
  bola12                    INTEGER CHECK (bola12 BETWEEN 1 AND 25),
  bola13                    INTEGER CHECK (bola13 BETWEEN 1 AND 25),
  bola14                    INTEGER CHECK (bola14 BETWEEN 1 AND 25),
  bola15                    INTEGER CHECK (bola15 BETWEEN 1 AND 25),
  arrecadacao_total         DOUBLE,
  ganhadores_15_numeros     INTEGER,
  cidade                    TEXT DEFAULT NULL,
  uf                        TEXT DEFAULT NULL,
  ganhadores_14_numeros     INTEGER,
  ganhadores_13_numeros     INTEGER,
  ganhadores_12_numeros     INTEGER,
  ganhadores_11_numeros     INTEGER,
  valor_rateio_15_numeros   DOUBLE,
  valor_rateio_14_numeros   DOUBLE,
  valor_rateio_13_numeros   DOUBLE,
  valor_rateio_12_numeros   DOUBLE,
  valor_rateio_11_numeros   DOUBLE,
  acumulado_15_numeros      DOUBLE,
  estimativa_premio         DOUBLE,
  valor_acumulado_especial  DOUBLE,
  CONSTRAINT bolas_unicas CHECK(
    bola1 NOT IN (bola2, bola3, bola4, bola5, bola6, bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola2 NOT IN (bola3, bola4, bola5, bola6, bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola3 NOT IN (bola4, bola5, bola6, bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola4 NOT IN (bola5, bola6, bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola5 NOT IN (bola6, bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola6 NOT IN (bola7, bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola7 NOT IN (bola8, bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola8 NOT IN (bola9, bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola9 NOT IN (bola10, bola11, bola12, bola13, bola14, bola15) AND
    bola10 NOT IN (bola11, bola12, bola13, bola14, bola15) AND
    bola11 NOT IN (bola12, bola13, bola14, bola15) AND
    bola12 NOT IN (bola13, bola14, bola15) AND
    bola13 NOT IN (bola14, bola15) AND
    bola14 != bola15
  )
);

CREATE TRIGGER IF NOT EXISTS on_concursos_insert AFTER INSERT ON concursos BEGIN

  INSERT INTO bolas_juntadas (concurso, bolas) VALUES (new.concurso, (1 << new.bola1-1) | (1 << new.bola2-1) | (1 << new.bola3-1) | (1 << new.bola4-1) | (1 << new.bola5-1) | (1 << new.bola6-1) | (1 << new.bola7-1) | (1 << new.bola8-1) | (1 << new.bola9-1) | (1 << new.bola10-1) | (1 << new.bola11-1) | (1 << new.bola12-1) | (1 << new.bola13-1) | (1 << new.bola14-1) | (1 << new.bola15-1));

  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola1);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola2);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola3);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola4);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola5);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola6);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola7);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola8);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola9);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola10);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola11);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola12);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola13);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola14);
  INSERT INTO bolas_sorteadas (concurso, bola) VALUES (new.concurso, new.bola15);
END;

CREATE TRIGGER IF NOT EXISTS on_concursos_delete AFTER DELETE ON concursos BEGIN
  DELETE FROM bolas_juntadas WHERE (concurso == old.concurso);
  DELETE FROM bolas_sorteadas WHERE (concurso == old.concurso);
  DELETE FROM ganhadores WHERE (concurso == old.concurso);
END;

CREATE TRIGGER IF NOT EXISTS on_concursos_chk_cidade AFTER INSERT ON concursos
WHEN new.cidade == "NULL" OR trim(new.cidade) == ""
BEGIN
  UPDATE concursos SET cidade=NULL WHERE concurso == new.concurso;
END;

CREATE TRIGGER IF NOT EXISTS on_concursos_chk_uf AFTER INSERT ON concursos
WHEN new.uf == "NULL" OR trim(new.uf) == ""
BEGIN
  UPDATE concursos SET uf=NULL WHERE concurso == new.concurso;
END;

DROP TABLE IF EXISTS bolas_juntadas;
CREATE TABLE bolas_juntadas (
  -- agrupamentos bitwise das bolas sorteadas nos concursos
  -- preenchida automaticamente i.e.: sem intervenção direta do usuário
  concurso  INTEGER,
  bolas     INTEGER,
  FOREIGN KEY (concurso) REFERENCES concursos(concurso)
);

DROP TABLE IF EXISTS bolas_sorteadas;
CREATE TABLE bolas_sorteadas (
  -- tabela conveniência p/facilitar análise das bolas sorteadas ao longo do
  -- tempo, preenchida automaticamente i.e.: sem intervenção direta do usuário
  concurso  INTEGER,
  bola      INTEGER,
  FOREIGN KEY (concurso) REFERENCES concursos(concurso)
);

DROP INDEX IF EXISTS ndx;
CREATE INDEX ndx ON bolas_sorteadas (concurso, bola);

DROP TABLE IF EXISTS ganhadores;
CREATE TABLE ganhadores (
  concurso  INTEGER NOT NULL,
  cidade    TEXT,
  uf        TEXT,
  FOREIGN KEY (concurso) REFERENCES concursos(concurso)
);

CREATE TRIGGER IF NOT EXISTS on_ganhadores_insert BEFORE INSERT ON ganhadores
WHEN new.cidade == "NULL" OR trim(new.cidade) == ""
BEGIN
  INSERT INTO ganhadores VALUES(new.concurso, NULL, new.uf);
  SELECT RAISE(IGNORE);   --> cancela inserção do registro original
END;

CREATE VIEW IF NOT EXISTS bitmasks AS
  -- listagem das "bitmasks" das bolas sorteados em cada concurso
  SELECT concurso, (
    WITH RECURSIVE bits (n, r) AS (
      VALUES (-1, "")
      UNION ALL
      SELECT n+1, (bolas >> n+1 & 1) || r FROM bits WHERE n < 25
    ) SELECT r FROM bits WHERE n == 24
  ) AS mask FROM bolas_juntadas;

CREATE VIEW IF NOT EXISTS info_bolas AS
  SELECT M AS concurso, bola, frequencia, latencia, (frequencia < u AND latencia >= v) AS atipico
  FROM (
    SELECT bola, count(bola) AS frequencia, (M-max(concurso)) AS latencia, M, (M*15.0/25) AS u, (25.0/15) AS v
    FROM (SELECT max(concurso) AS M FROM concursos), bolas_sorteadas
    GROUP BY bola
  );

COMMIT;
