/**
 * Consulta das sequências de 2+ incidências de sucesso – concurso com 1+
 * acertadores das 15 bolas – na mais recente série de concursos da Lotofácil,
 * agregando o número serial do concurso que termina a sequência, as datas dos
 * concursos e total de ganhadores entre o concurso inicial e final inclusive,
 * preservando o resultado na tabela temporária "repeticoes".
*/

drop table if exists urna;
create temp table urna(id INTEGER);

-- tenta preservar o rowid do registro incumbente da tabela "param"
-- usando o valor impossível "0" se não existir
insert into urna
  select case exists(select 1 from param where status)
    when 1 then (select rowid from param where status) else 0 end;

-- apêndice de registro incumbente contendo a sequência de premiação principal
insert into param (s, status)
  select group_concat(ganhadores_15_numeros>0, ""), 1 from concursos;

/**
 * Cria a tabela temporária das sequências de 2+ incidências de sucesso
 * pormenorizadas, tabulando:
 *
 *    ndx         --> número de ordem da sequência
 *    ini         --> número serial do concurso que inicia a sequência
 *    iniDate     --> data de realização do concurso que inicia a sequência
 *    fim         --> número serial do concurso que termina a sequência
 *    fimDate     --> data de realização do concurso que termina a sequência
 *    len         --> número de concursos desde "início" até "fim" inclusive
 *    ganhadores  --> número de ganhadores desde "início" até "fim" inclusive
*/
drop table if exists repeticoes;
create temp table repeticoes as
  with cte as (
    select ndx, ini, ini+len-1 as fim, len, data_sorteio as iniDate
    from incidencias join concursos on ini == concurso
    where len > 1
  ) select ndx, ini, iniDate, fim, data_sorteio as fimDate, len, (
        select sum(ganhadores_15_numeros)
        from concursos where concurso between ini and fim
      ) as ganhadores
    from cte join concursos on fim == concurso;

-- "pretty print" da tabela "repetições" ordenada pelo número de ganhadores
select printf("%3d", ndx),
  printf("%4d", ini), strftime("%d-%m-%Y", iniDate),
  printf("%4d", fim), strftime("%d-%m-%Y", fimDate),
  printf("%2d", len), printf("%3d", ganhadores),
  printf("%5.2f", ganhadores/1.0/len)
from repeticoes order by ganhadores;

-- restaura a tabela "param" excluindo o registro incumbente que volta a ser
-- aquele cujo rowid foi ínicialmente preservado na "urna"
delete from param where status;
update param set status=1 where rowid == (select id from urna);
