/* ============================================================================
   QUERY SIMPLIFICADA: priorización de teléfono + alertas de contacto
   ============================================================================
   Se apoya 100% en columnas que tu query original YA calcula y que tú
   ya validaste (meses_con_gestion, enero..agosto, enero_tlf..agosto_tlf).
   No hay cálculos de "meses de diferencia" -- solo se leen esas columnas
   directamente, para que puedas comparar 1 a 1 contra el Excel de siempre.

   Columnas que se agregan al final:

     cliente_nuevo_sin_historico  -> 'SI' si meses_con_gestion = 1
                                      (recién asignado, sin base histórica;
                                      el resto de alertas se apaga para
                                      estos clientes)

     mes_ultimo_ce / telefono_ultimo_ce -> el mes MÁS RECIENTE con ce y
                                      el teléfono con el que se logró

     A1_score_mal_priorizado      -> 'NO' o 'SI - pos X': telefono_ultimo_ce
                                      existe en la asignación pero no es
                                      telefono1
     A2_telefono_no_asignado      -> 'SI'/'NO': telefono_ultimo_ce ni
                                      siquiera está en la asignación

     sin_ce_ultimos_3_meses       -> 'SI' si mayo, junio Y julio son
                                      'nc' los tres (los 3 meses cerrados
                                      más recientes; agosto se deja fuera
                                      por ser el mes en curso, aún
                                      incompleto)
     sin_ce_todo_2026             -> 'SI' si NINGUNA columna de enero a
                                      agosto dice 'ce' (nunca tuvo
                                      contacto en todo el año)

     necesita_revision            -> 'SI'/'NO' resumen de todo lo anterior

   OJO: escrita para el corte de agosto 2026. Si corres esto otro mes,
   ajusta los 2 puntos marcados "-- AJUSTAR CADA MES" (el codmes de
   basejulio, y qué 3 columnas usar como "últimos 3 meses cerrados").
   ============================================================================ */

with tipis as (
    select 
        periodo as mes, 
        [contact id] as cu, 
        [wrap-up], 
        right(dnis,9) as telefono, 
        orden = row_number() over(partition by [contact id], periodo order by fecha_key asc) 
    from ykr_tb_cob_intentos as a
    inner join (
        select conlusion_cloud as conclusion, 1 as resultado 
        from ob_conclusiones_cloud_5 
        where tipo_resultado in ('pdp','pdp - fdp','contacto - efectivo')
    ) as b on b.conclusion=a.[wrap-up]
    where b.resultado=1
    and [campaign name] in ('cob_bpe_00','cob_bpe_01','cob_bpe_02')

    union all 

    select 
        periodo as mes, 
        [contact id] as cu, 
        [wrap-up], 
        right(dnis,9) as telefono, 
        orden = row_number() over(partition by [contact id], periodo order by fecha_key asc) 
    from ykr_tb_cob_intentos_bkp as a
    inner join (
        select conlusion_cloud as conclusion, 1 as resultado 
        from ob_conclusiones_cloud_5 
        where tipo_resultado in ('pdp','pdp - fdp','contacto - efectivo')
    ) as b on b.conclusion=a.[wrap-up]
    where b.resultado=1
    and [campaign name] in ('cob_bpe_00','cob_bpe_01','cob_bpe_02')
    and cast(periodo as int) >= 202601
),
tipis_unico as (
    select * from tipis where orden=1
),
basejulio as (
    select 
        *,
        row_number() over (partition by codunicocli order by (select null)) as rn
    from cob_trf_bpe_asignacion_historico
    where codmes = '202608'  -- AJUSTAR CADA MES
    and tramo_asignacion in ('temprana','intermedia','tardia') 
),
clientes_julio as (
    select * from basejulio where rn = 1
),
presencia_historica as (
    select 
        codunicocli as cu,
        count(distinct codmes) as meses_asignados,
        max(case when codmes = '202601' then 1 else 0 end) as pres_enero,
        max(case when codmes = '202602' then 1 else 0 end) as pres_febrero,
        max(case when codmes = '202603' then 1 else 0 end) as pres_marzo,
        max(case when codmes = '202604' then 1 else 0 end) as pres_abril,
        max(case when codmes = '202605' then 1 else 0 end) as pres_mayo,
        max(case when codmes = '202606' then 1 else 0 end) as pres_junio,
        max(case when codmes = '202607' then 1 else 0 end) as pres_julio,
        max(case when codmes = '202608' then 1 else 0 end) as pres_agosto
    from cob_trf_bpe_asignacion_historico
    where codmes between '202601' and '202608'
    and tramo_asignacion in ('temprana','intermedia','tardia')
    group by codunicocli
),
gestion_historica as (
    select 
        cu,
        max(case when mes = '202601' then 'ce' else null end) as enero_res,
        max(case when mes = '202602' then 'ce' else null end) as febrero_res,
        max(case when mes = '202603' then 'ce' else null end) as marzo_res,
        max(case when mes = '202604' then 'ce' else null end) as abril_res,
        max(case when mes = '202605' then 'ce' else null end) as mayo_res,
        max(case when mes = '202606' then 'ce' else null end) as junio_res,
        max(case when mes = '202607' then 'ce' else null end) as julio_res,
        max(case when mes = '202608' then 'ce' else null end) as agosto_res,
        
        max(case when mes = '202601' then telefono else null end) as enero_tlf,
        max(case when mes = '202602' then telefono else null end) as febrero_tlf,
        max(case when mes = '202603' then telefono else null end) as marzo_tlf,
        max(case when mes = '202604' then telefono else null end) as abril_tlf,
        max(case when mes = '202605' then telefono else null end) as mayo_tlf,
        max(case when mes = '202606' then telefono else null end) as junio_tlf,
        max(case when mes = '202607' then telefono else null end) as julio_tlf,
        max(case when mes = '202608' then telefono else null end) as agosto_tlf
        
    from tipis_unico
    where mes between '202601' and '202608'
    group by cu
),
gestion_julio as (
    select 
        cu, 
        'contacto' as resultado_agosto, 
        telefono as tlf_mejor_resultado
    from tipis_unico
    where mes = '202608'
),

/* ------------------------------------------------------------------------
   BASE_FINAL: idéntico a tu query original (mismas columnas, select c.*)
   ------------------------------------------------------------------------ */
base_final as (
    select 
        c.*, 
        
        coalesce(j.resultado_agosto, 'sin contacto') as resultado_agosto_resumen,
        j.tlf_mejor_resultado,
        
        case when cast(c.telefono1 as varchar)='0' then null else c.telefono1 end as tlf1_limpio,
        case when cast(c.telefono2 as varchar)='0' then null else c.telefono2 end as tlf2_limpio,
        case when cast(c.telefono3 as varchar)='0' then null else c.telefono3 end as tlf3_limpio,
        case when cast(c.telefono4 as varchar)='0' then null else c.telefono4 end as tlf4_limpio,
        case when cast(c.telefono5 as varchar)='0' then null else c.telefono5 end as tlf5_limpio,
        case when cast(c.telefono6 as varchar)='0' then null else c.telefono6 end as tlf6_limpio,
        case when cast(c.telefono7 as varchar)='0' then null else c.telefono7 end as tlf7_limpio,
        case when cast(c.telefono8 as varchar)='0' then null else c.telefono8 end as tlf8_limpio,
        case when cast(c.telefono9 as varchar)='0' then null else c.telefono9 end as tlf9_limpio,
        case when cast(c.telefono10 as varchar)='0' then null else c.telefono10 end as tlf10_limpio,
        
        coalesce(p.meses_asignados, 0) as meses_con_gestion,
        
        case when p.pres_enero = 1 then coalesce(h.enero_res, 'nc') else null end as enero,
        case when p.pres_febrero = 1 then coalesce(h.febrero_res, 'nc') else null end as febrero,
        case when p.pres_marzo = 1 then coalesce(h.marzo_res, 'nc') else null end as marzo,
        case when p.pres_abril = 1 then coalesce(h.abril_res, 'nc') else null end as abril,
        case when p.pres_mayo = 1 then coalesce(h.mayo_res, 'nc') else null end as mayo,
        case when p.pres_junio = 1 then coalesce(h.junio_res, 'nc') else null end as junio,
        case when p.pres_julio = 1 then coalesce(h.julio_res, 'nc') else null end as julio,
        case when p.pres_agosto = 1 then coalesce(h.agosto_res, 'nc') else null end as agosto,
        
        case when p.pres_enero = 1 then h.enero_tlf else null end as enero_tlf,
        case when p.pres_febrero = 1 then h.febrero_tlf else null end as febrero_tlf,
        case when p.pres_marzo = 1 then h.marzo_tlf else null end as marzo_tlf,
        case when p.pres_abril = 1 then h.abril_tlf else null end as abril_tlf,
        case when p.pres_mayo = 1 then h.mayo_tlf else null end as mayo_tlf,
        case when p.pres_junio = 1 then h.junio_tlf else null end as junio_tlf,
        case when p.pres_julio = 1 then h.julio_tlf else null end as julio_tlf,
        case when p.pres_agosto = 1 then h.agosto_tlf else null end as agosto_tlf
        
    from clientes_julio c
    left join gestion_julio j on c.codunicocli = j.cu
    left join presencia_historica p on c.codunicocli = p.cu
    left join gestion_historica h on c.codunicocli = h.cu
),

/* ------------------------------------------------------------------------
   MESES_CE: despivoteo de enero..agosto -> filas, solo donde hubo ce,
   cada fila con su número de mes (1=enero ... 8=agosto).
   ------------------------------------------------------------------------ */
meses_ce as (
    select
        b.codunicocli,
        v.mes_num,
        v.telefono
    from base_final b
    cross apply (values
        (1, b.enero,   b.enero_tlf),
        (2, b.febrero, b.febrero_tlf),
        (3, b.marzo,   b.marzo_tlf),
        (4, b.abril,   b.abril_tlf),
        (5, b.mayo,    b.mayo_tlf),
        (6, b.junio,   b.junio_tlf),
        (7, b.julio,   b.julio_tlf),
        (8, b.agosto,  b.agosto_tlf)
    ) as v(mes_num, resultado, telefono)
    where v.resultado = 'ce'
      and v.telefono is not null
),

/* ------------------------------------------------------------------------
   ULTIMO_CE: nos quedamos con el mes más reciente (mes_num más alto)
   por cliente.
   ------------------------------------------------------------------------ */
ultimo_ce as (
    select codunicocli, mes_num as mes_ultimo_ce_num, telefono as telefono_ultimo_ce
    from (
        select
            codunicocli, mes_num, telefono,
            row_number() over (partition by codunicocli order by mes_num desc) as rn
        from meses_ce
    ) x
    where rn = 1
),

/* ------------------------------------------------------------------------
   TELEFONOS_ASIGNADOS: despivoteo de telefono1_limpio..telefono10_limpio
   con su posición.
   ------------------------------------------------------------------------ */
telefonos_asignados as (
    select b.codunicocli, v.posicion, v.telefono
    from base_final b
    cross apply (values
        (1,  b.tlf1_limpio), (2,  b.tlf2_limpio), (3, b.tlf3_limpio),
        (4,  b.tlf4_limpio), (5,  b.tlf5_limpio), (6, b.tlf6_limpio),
        (7,  b.tlf7_limpio), (8,  b.tlf8_limpio), (9, b.tlf9_limpio),
        (10, b.tlf10_limpio)
    ) as v(posicion, telefono)
    where v.telefono is not null
),

/* ------------------------------------------------------------------------
   CLASIFICACION: cruce del último ce contra su posición en la asignación
   ------------------------------------------------------------------------ */
clasificacion as (
    select
        b.codunicocli,
        u.mes_ultimo_ce_num,
        u.telefono_ultimo_ce,
        ta.posicion as posicion_telefono_ultimo_ce
    from base_final b
    left join ultimo_ce u on u.codunicocli = b.codunicocli
    left join telefonos_asignados ta
        on ta.codunicocli = u.codunicocli
        and ta.telefono = u.telefono_ultimo_ce
)

/* ============================================================================
   RESULTADO FINAL
   ============================================================================ */
select
    bf.*,

    case when bf.meses_con_gestion = 1 then 'SI' else 'NO' end as cliente_nuevo_sin_historico,

    case cl.mes_ultimo_ce_num
        when 1 then 'enero' when 2 then 'febrero' when 3 then 'marzo' when 4 then 'abril'
        when 5 then 'mayo' when 6 then 'junio' when 7 then 'julio' when 8 then 'agosto'
        else null
    end as mes_ultimo_ce,
    cl.telefono_ultimo_ce,

    case
        when bf.meses_con_gestion = 1 then 'NO'  -- cliente nuevo, no se evalua todavia
        when cl.telefono_ultimo_ce is null then 'NO'
        when cl.posicion_telefono_ultimo_ce = 1 then 'NO'
        when cl.posicion_telefono_ultimo_ce is not null
             then 'SI - pos ' + cast(cl.posicion_telefono_ultimo_ce as varchar(2))
        else 'NO'
    end as A1_score_mal_priorizado,

    case
        when bf.meses_con_gestion = 1 then 'NO'
        when cl.telefono_ultimo_ce is not null and cl.posicion_telefono_ultimo_ce is null then 'SI'
        else 'NO'
    end as A2_telefono_no_asignado,

    -- AJUSTAR CADA MES: los 3 meses "cerrados" más recientes (se deja
    -- fuera el mes en curso porque todavía está incompleto)
    case
        when bf.meses_con_gestion = 1 then 'NO'
        when bf.mayo = 'nc' and bf.junio = 'nc' and bf.julio = 'nc' then 'SI'
        else 'NO'
    end as sin_ce_ultimos_3_meses,

    case
        when bf.meses_con_gestion = 1 then 'NO'
        when coalesce(bf.enero,'x')  <> 'ce' and coalesce(bf.febrero,'x') <> 'ce'
         and coalesce(bf.marzo,'x')  <> 'ce' and coalesce(bf.abril,'x')   <> 'ce'
         and coalesce(bf.mayo,'x')   <> 'ce' and coalesce(bf.junio,'x')   <> 'ce'
         and coalesce(bf.julio,'x')  <> 'ce' and coalesce(bf.agosto,'x')  <> 'ce'
        then 'SI'
        else 'NO'
    end as sin_ce_todo_2026,

    case
        when bf.meses_con_gestion = 1 then 'NO'
        when (cl.posicion_telefono_ultimo_ce is not null and cl.posicion_telefono_ultimo_ce <> 1) then 'SI'
        when (cl.telefono_ultimo_ce is not null and cl.posicion_telefono_ultimo_ce is null) then 'SI'
        when (bf.mayo = 'nc' and bf.junio = 'nc' and bf.julio = 'nc') then 'SI'
        when (coalesce(bf.enero,'x')  <> 'ce' and coalesce(bf.febrero,'x') <> 'ce'
          and coalesce(bf.marzo,'x')  <> 'ce' and coalesce(bf.abril,'x')   <> 'ce'
          and coalesce(bf.mayo,'x')   <> 'ce' and coalesce(bf.junio,'x')   <> 'ce'
          and coalesce(bf.julio,'x')  <> 'ce' and coalesce(bf.agosto,'x')  <> 'ce') then 'SI'
        else 'NO'
    end as necesita_revision

from base_final bf
left join clasificacion cl on cl.codunicocli = bf.codunicocli
order by bf.codunicocli;
