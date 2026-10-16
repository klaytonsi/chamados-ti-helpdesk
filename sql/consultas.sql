-- EN: SQL queries for the IT helpdesk analysis (SQLite). Table: chamados.
-- PT: Consultas SQL da análise de helpdesk de TI (SQLite). Tabela: chamados.
--
-- EN: Dates are stored as text 'YYYY-MM-DD HH:MM:SS', so julianday() works.
--     julianday() returns days; multiply by 24 to get hours.
-- PT: Datas ficam como texto 'YYYY-MM-DD HH:MM:SS', então julianday() funciona.
--     julianday() retorna dias; multiplique por 24 para obter horas.
--
-- EN: Resolution time only makes sense for closed tickets (status = 'Fechado').
-- PT: Tempo de resolução só faz sentido para chamados fechados (status = 'Fechado').


-- [Q1] Tempo médio de resolução por categoria / Average resolution time by category
-- EN: Which categories take the longest to solve? (hours)
-- PT: Quais categorias demoram mais para resolver? (horas)
SELECT
    categoria,
    COUNT(*) AS chamados_fechados,
    ROUND(AVG((julianday(data_fechamento) - julianday(data_abertura)) * 24), 1)
        AS media_horas
FROM chamados
WHERE status = 'Fechado'
GROUP BY categoria
ORDER BY media_horas DESC;


-- [Q2] % geral dentro do SLA / Overall % within SLA
-- EN: A ticket is within SLA when resolution hours <= sla_horas.
-- PT: Um chamado está dentro do SLA quando as horas de resolução <= sla_horas.
WITH fechados AS (
    SELECT
        sla_horas,
        (julianday(data_fechamento) - julianday(data_abertura)) * 24 AS horas
    FROM chamados
    WHERE status = 'Fechado'
)
SELECT
    COUNT(*) AS fechados,
    SUM(CASE WHEN horas <= sla_horas THEN 1 ELSE 0 END) AS dentro_sla,
    ROUND(100.0 * SUM(CASE WHEN horas <= sla_horas THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS pct_dentro_sla
FROM fechados;


-- [Q3] % dentro do SLA por prioridade / % within SLA by priority
-- EN: Same rule as Q2, split by priority (the SLA target differs per priority).
-- PT: Mesma regra da Q2, separada por prioridade (a meta de SLA muda por prioridade).
WITH fechados AS (
    SELECT
        prioridade,
        sla_horas,
        (julianday(data_fechamento) - julianday(data_abertura)) * 24 AS horas
    FROM chamados
    WHERE status = 'Fechado'
)
SELECT
    prioridade,
    sla_horas,
    COUNT(*) AS fechados,
    SUM(CASE WHEN horas <= sla_horas THEN 1 ELSE 0 END) AS dentro_sla,
    ROUND(100.0 * SUM(CASE WHEN horas <= sla_horas THEN 1 ELSE 0 END)
          / COUNT(*), 1) AS pct_dentro_sla
FROM fechados
GROUP BY prioridade, sla_horas
ORDER BY sla_horas;


-- [Q4] Picos de abertura por dia da semana e hora / Opening peaks by weekday and hour
-- EN: strftime('%w') gives 0 = Sunday ... 6 = Saturday; '%H' gives the hour.
-- PT: strftime('%w') retorna 0 = domingo ... 6 = sábado; '%H' retorna a hora.
SELECT
    CAST(strftime('%w', data_abertura) AS INTEGER) AS dia_semana,
    CAST(strftime('%H', data_abertura) AS INTEGER) AS hora,
    COUNT(*) AS chamados
FROM chamados
GROUP BY dia_semana, hora
ORDER BY dia_semana, hora;


-- [Q5] Ranking de técnicos / Technician ranking
-- EN: Ranked by % within SLA (higher is better); ties broken by lower average time.
--     RANK() is a window function: it numbers rows after the sorting rule.
-- PT: Ordenado por % dentro do SLA (maior é melhor); desempate pelo menor tempo médio.
--     RANK() é uma window function: numera as linhas conforme a regra de ordenação.
WITH fechados AS (
    SELECT
        tecnico,
        sla_horas,
        (julianday(data_fechamento) - julianday(data_abertura)) * 24 AS horas
    FROM chamados
    WHERE status = 'Fechado'
),
por_tecnico AS (
    SELECT
        tecnico,
        COUNT(*) AS chamados_fechados,
        ROUND(AVG(horas), 1) AS media_horas,
        ROUND(100.0 * SUM(CASE WHEN horas <= sla_horas THEN 1 ELSE 0 END)
              / COUNT(*), 1) AS pct_dentro_sla
    FROM fechados
    GROUP BY tecnico
)
SELECT
    RANK() OVER (ORDER BY pct_dentro_sla DESC, media_horas ASC) AS posicao,
    tecnico,
    chamados_fechados,
    media_horas,
    pct_dentro_sla
FROM por_tecnico
ORDER BY posicao;
