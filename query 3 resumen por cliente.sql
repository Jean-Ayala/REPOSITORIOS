/* ============================================================================
   QUERY 3: RESUMEN DE ALERTAS POR CLIENTE (1 fila por cliente)
   ============================================================================
   Qué hace: toma la misma lógica de la Query 2, pero en vez de devolver
   una fila por cada alerta encontrada, la resume en UNA fila por cliente
   con:
     - un flag general (necesita_revision = SI/NO)
     - el detalle de cuántas alertas de cada tipo tiene
     - el peor tipo de alerta (para poder priorizar a quién revisar primero)
   Corre sola, no depende de la Query 1 ni de la Query 2.
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
    where codmes = '202608'
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

base_final as (
    select 
        c.codunicocli,
        c.telefono1, c.telefono2, c.telefono3, c.telefono4, c.telefono5,
        c.telefono6, c.telefono7, c.telefono8, c.telefono9, c.telefono10,

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

telefonos_ce as (
    select
        b.codunicocli,
        v.mes,
        v.telefono_ce
    from base_final b
    cross apply (values
        ('enero',   b.enero,   b.enero_tlf),
        ('febrero', b.febrero, b.febrero_tlf),
        ('marzo',   b.marzo,   b.marzo_tlf),
        ('abril',   b.abril,   b.abril_tlf),
        ('mayo',    b.mayo,    b.mayo_tlf),
        ('junio',   b.junio,   b.junio_tlf),
        ('julio',   b.julio,   b.julio_tlf),
        ('agosto',  b.agosto,  b.agosto_tlf)
    ) as v(mes, resultado_mes, telefono_ce)
    where v.resultado_mes = 'ce'
      and v.telefono_ce is not null
),

telefonos_asignados as (
    select
        b.codunicocli,
        v.posicion,
        v.telefono
    from base_final b
    cross apply (values
        (1,  b.tlf1_limpio),
        (2,  b.tlf2_limpio),
        (3,  b.tlf3_limpio),
        (4,  b.tlf4_limpio),
        (5,  b.tlf5_limpio),
        (6,  b.tlf6_limpio),
        (7,  b.tlf7_limpio),
        (8,  b.tlf8_limpio),
        (9,  b.tlf9_limpio),
        (10, b.tlf10_limpio)
    ) as v(posicion, telefono)
    where v.telefono is not null
),

alertas_priorizacion as (
    select
        t.codunicocli,
        t.mes,
        t.telefono_ce,
        ta.posicion as posicion_en_asignacion,
        case
            when ta.posicion = 1 then 'ok'
            when ta.posicion is not null then 'A1_SCORE_MAL_PRIORIZADO'
            else 'A2_TELEFONO_NO_ASIGNADO'
        end as tipo_alerta
    from telefonos_ce t
    left join telefonos_asignados ta
        on ta.codunicocli = t.codunicocli
        and ta.telefono = t.telefono_ce
),

alertas_telefonos_muertos as (
    select
        ta.codunicocli,
        ta.posicion as posicion_en_asignacion,
        ta.telefono,
        'A3_TELEFONO_SIN_CONTACTO' as tipo_alerta
    from telefonos_asignados ta
    where not exists (
        select 1 
        from telefonos_ce t 
        where t.codunicocli = ta.codunicocli 
        and t.telefono_ce = ta.telefono
    )
),

/* ------------------------------------------------------------------------
   TODAS_LAS_ALERTAS: unimos A1/A2/A3 en una sola tabla intermedia
   (mismo resultado que la Query 2, pero aquí es un paso intermedio
   para poder agregarlo por cliente después)
   ------------------------------------------------------------------------ */
todas_las_alertas as (
    select codunicocli, tipo_alerta from alertas_priorizacion where tipo_alerta <> 'ok'
    union all
    select codunicocli, tipo_alerta from alertas_telefonos_muertos
)

/* ============================================================================
   RESUMEN FINAL: 1 fila por cliente
   ============================================================================ */
select
    codunicocli,

    -- flag simple para filtrar rápido en Excel / Power BI
    case when count(*) > 0 then 'SI' else 'NO' end as necesita_revision,

    -- detalle: cuántas alertas de cada tipo tiene ese cliente
    sum(case when tipo_alerta = 'A1_SCORE_MAL_PRIORIZADO' then 1 else 0 end) as cant_A1_score_mal_priorizado,
    sum(case when tipo_alerta = 'A2_TELEFONO_NO_ASIGNADO' then 1 else 0 end) as cant_A2_telefono_no_asignado,
    sum(case when tipo_alerta = 'A3_TELEFONO_SIN_CONTACTO' then 1 else 0 end) as cant_A3_telefono_sin_contacto,

    -- para priorizar: la alerta "más grave" que tiene el cliente
    -- (orden de gravedad sugerido: A2 > A1 > A3, ajústalo si tu criterio es otro)
    min(case tipo_alerta
            when 'A2_TELEFONO_NO_ASIGNADO' then 1
            when 'A1_SCORE_MAL_PRIORIZADO' then 2
            when 'A3_TELEFONO_SIN_CONTACTO' then 3
        end) as ranking_gravedad

from todas_las_alertas
group by codunicocli

order by ranking_gravedad, codunicocli;
