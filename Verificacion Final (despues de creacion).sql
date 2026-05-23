USE SalonBelleza_CBB;
GO
-- ============================================================
-- VERIFICACIÓN FINAL
-- ============================================================

SELECT
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    c.COLUMN_NAME,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c
    ON t.TABLE_SCHEMA = c.TABLE_SCHEMA
    AND t.TABLE_NAME  = c.TABLE_NAME
WHERE c.COLUMN_NAME = 'Sucursal'
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME;
GO