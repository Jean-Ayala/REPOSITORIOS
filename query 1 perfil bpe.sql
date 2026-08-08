/* ============================================================================
   QUERY 1: PERFIL BPE - asignación de agosto + histórico de gestión enero-agosto
   ============================================================================
   Qué hace: por cada cliente asignado en agosto (tramo temprana/intermedia/
   tardia), arma su "ficha" completa: datos base + teléfonos limpios +
   una columna por cada mes (enero...agosto) que dice si tuvo contacto
   efectivo ('ce'), no contacto ('nc') o no estuvo asignado ese mes (null),
   más el teléfono con el que se logró el contacto en cada mes.
   Este es el Excel con las columnas azules (asignación) y amarillas (ce).
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
    -- se filtra que el cliente pertenezca a estos tramos en la foto actual
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
    -- evalúa independientemente si en cada mes histórico el cu estuvo en alguno de los 3 tramos
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
)
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
left join gestion_historica h on c.codunicocli = h.cu;
