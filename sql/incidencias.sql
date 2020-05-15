/**
 *  Acessa o único registro incumbente da tabela "param", para sequencialmente
 *  alistar as posições iniciais e comprimentos de subsequências somente de "1"
 *  em "s" – o que equivale a identificar os períodos de sucessos consecutivos
 *  numa sequência de resultados lógicos – tabulando:
 *
 *    ndx: número de ordem da identificação
 *    ini: posição inicial da subsequência  – número serial do concurso inicial
 *    len: comprimento da subsequência      – número de concursos consecutivos
*/
create view if not exists incidencias as
  with recursive par (s) as (
    select s from param where status
  ), ones (n, i) as (
    select 1, instr(s, "1") from par  -- posição inicial da primeira
    union all
    select n+1, i+instr(substr(s, i+1), "01")+1 as k  -- posição inicial da
      from par, ones where k > i+1                     -- segunda em diante
  ) select n as ndx, i as ini,
        instr(substr(s, i), "0")-1 as len
      from (
        select s||"0" as s  -- apêndice "0" é artifício p/calcular comprimento
          from par          -- de possível subsequência na extremidade direita
      ), ones;
