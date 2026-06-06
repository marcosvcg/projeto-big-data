CREATE TABLE IF NOT EXISTS ibge_estados (
    estado           TEXT,
    uf               INTEGER,
    gentilico        TEXT,
    governador       TEXT,
    capital          TEXT,
    area_km2         NUMERIC(14, 3),
    populacao        BIGINT,
    densidade        NUMERIC(10, 2),
    matriculas       INTEGER,
    idh              NUMERIC(5, 3),
    receitas         NUMERIC(18, 5),
    despesas         NUMERIC(18, 5),
    renda_per_capita NUMERIC(10, 2),
    veiculos         INTEGER
);

-- Região geográfica por estado (necessário para agregações macrorregionais)
ALTER TABLE ibge_estados
    ADD COLUMN IF NOT EXISTS regiao TEXT;

COPY ibge_estados (
    estado, uf, gentilico, governador, capital,
    area_km2, populacao, densidade, matriculas, idh,
    receitas, despesas, renda_per_capita, veiculos
)
FROM '/docker-entrypoint-initdb.d/dados_ibge_tratados.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE,
    DELIMITER ',',
    ENCODING 'UTF8'
);

-- =============================================================================
-- Mapeamento UF → grande região
-- =============================================================================

UPDATE ibge_estados SET regiao = CASE estado
    WHEN 'Acre'                THEN 'Norte'
    WHEN 'Amapá'               THEN 'Norte'
    WHEN 'Amazonas'            THEN 'Norte'
    WHEN 'Pará'                THEN 'Norte'
    WHEN 'Rondônia'            THEN 'Norte'
    WHEN 'Roraima'             THEN 'Norte'
    WHEN 'Tocantins'           THEN 'Norte'
    WHEN 'Alagoas'             THEN 'Nordeste'
    WHEN 'Bahia'               THEN 'Nordeste'
    WHEN 'Ceará'               THEN 'Nordeste'
    WHEN 'Maranhão'            THEN 'Nordeste'
    WHEN 'Paraíba'             THEN 'Nordeste'
    WHEN 'Pernambuco'          THEN 'Nordeste'
    WHEN 'Piauí'               THEN 'Nordeste'
    WHEN 'Rio Grande do Norte' THEN 'Nordeste'
    WHEN 'Sergipe'             THEN 'Nordeste'
    WHEN 'Distrito Federal'    THEN 'Centro-Oeste'
    WHEN 'Goiás'               THEN 'Centro-Oeste'
    WHEN 'Mato Grosso'         THEN 'Centro-Oeste'
    WHEN 'Mato Grosso do Sul'  THEN 'Centro-Oeste'
    WHEN 'Espírito Santo'      THEN 'Sudeste'
    WHEN 'Minas Gerais'        THEN 'Sudeste'
    WHEN 'Rio de Janeiro'      THEN 'Sudeste'
    WHEN 'São Paulo'           THEN 'Sudeste'
    WHEN 'Paraná'              THEN 'Sul'
    WHEN 'Rio Grande do Sul'   THEN 'Sul'
    WHEN 'Santa Catarina'      THEN 'Sul'
END;

-- Desafio 1: Cálculo de Densidade Demográfica
CREATE OR REPLACE VIEW v_densidade_demografica AS
SELECT
    estado,
    regiao,
    populacao,
    area_km2,
    ROUND(populacao::NUMERIC / area_km2, 5) AS densidade_calculada
FROM ibge_estados
ORDER BY densidade_calculada DESC;

-- Desafio 2: Agregação Macrorregional
CREATE OR REPLACE VIEW v_agregacao_macrorregional AS
SELECT
    regiao,
    COUNT(*)                             AS qtd_estados,
    ROUND(AVG(idh)::NUMERIC, 3)          AS media_idh,
    ROUND(AVG(renda_per_capita)::NUMERIC, 2) AS media_renda_per_capita
FROM ibge_estados
GROUP BY regiao
ORDER BY regiao;

-- Desafio 3: Filtragem por Linha de Corte Dinâmica
CREATE OR REPLACE VIEW v_frota_acima_da_media AS
SELECT
    estado,
    regiao,
    veiculos,
    ROUND((SELECT AVG(veiculos) FROM ibge_estados)::NUMERIC, 2) AS media_nacional
FROM ibge_estados
WHERE veiculos > (SELECT AVG(veiculos) FROM ibge_estados)
ORDER BY veiculos DESC;

-- Desafio 4: Análise de Vulnerabilidade Social (renda < 1500 e matrículas > 200k)
CREATE OR REPLACE VIEW v_vulnerabilidade_social AS
SELECT
    estado,
    regiao,
    renda_per_capita,
    matriculas,
    idh
FROM ibge_estados
WHERE renda_per_capita < 1500
  AND matriculas > 200000
ORDER BY renda_per_capita ASC;

-- Extras úteis para o dashboard
CREATE OR REPLACE VIEW v_resumo_por_regiao AS
SELECT
    regiao,
    COUNT(*)                                  AS qtd_estados,
    SUM(populacao)                            AS populacao_total,
    SUM(veiculos)                             AS veiculos_total,
    ROUND(AVG(idh)::NUMERIC, 3)              AS media_idh,
    ROUND(AVG(renda_per_capita)::NUMERIC, 2) AS media_renda,
    ROUND(AVG(densidade)::NUMERIC, 2)        AS media_densidade
FROM ibge_estados
GROUP BY regiao
ORDER BY populacao_total DESC;
