-- ============================================================
-- PARTE B: EJECUTAR EN COCHABAMBA (192.168.0.24)
-- Crea el Linked Server apuntando a Santa Cruz
-- ============================================================

EXEC sp_dropserver 'SC_NODE', 'droplogins';

EXEC sp_addlinkedserver
    @server     = N'SC_NODE',
    @srvproduct = N'',
    @provider   = N'SQLNCLI',
    @datasrc    = N'192.168.0.17';

EXEC sp_serveroption @server = N'SC_NODE', @optname = N'data access',          @optvalue = N'true';
EXEC sp_serveroption @server = N'SC_NODE', @optname = N'rpc out',              @optvalue = N'true';
EXEC sp_serveroption @server = N'SC_NODE', @optname = N'collation compatible', @optvalue = N'true';

EXEC sp_addlinkedsrvlogin
    @rmtsrvname  = N'SC_NODE',
    @useself     = N'false',
    @locallogin  = NULL,
    @rmtuser     = N'sa',
    @rmtpassword = N'Coco2025!';

EXEC sp_testlinkedserver N'SC_NODE';

---------------------------------------------------------
--CHANGE TRACKING
---------------------------------------------------------

USE SalonBelleza_CBB;

ALTER DATABASE SalonBelleza_CBB
    SET CHANGE_TRACKING = ON
    (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);

ALTER TABLE Servicios.CategoriaServicio    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Servicios.SubcategoriaServicio ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Servicios.Servicio             ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Servicios.ServicioPrecio       ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Marketing.Promocion            ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Marketing.PromocionServicio    ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Inventario.Producto            ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Inventario.ProductoPrecio      ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Inventario.Proveedor           ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Ventas.MetodoPago              ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Agenda.EstadoCita              ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE RRHH.Rol                       ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Seguridad.Rol                  ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);
ALTER TABLE Notificaciones.TipoNotificacion ENABLE CHANGE_TRACKING WITH (TRACK_COLUMNS_UPDATED = ON);



