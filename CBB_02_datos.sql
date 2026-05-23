-- ============================================================
-- COCO Salón de Belleza · SalonBelleza_CBB
-- Archivo: CBB_02_datos.sql
-- Descripción: Datos iniciales del catálogo (tablas replicadas)
--              + SPs de sincronización para recibir datos de SC
-- ============================================================

USE SalonBelleza_CBB;
GO

-- ── SPs para recibir sincronización desde Santa Cruz ─────────

CREATE OR ALTER PROCEDURE dbo.SP_InsertarCategoria
    @CategoriaID INT, @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Servicios.CategoriaServicio ON;
    IF NOT EXISTS (SELECT 1 FROM Servicios.CategoriaServicio WHERE CategoriaID = @CategoriaID)
        INSERT INTO Servicios.CategoriaServicio (CategoriaID, Nombre) VALUES (@CategoriaID, @Nombre);
    ELSE
        UPDATE Servicios.CategoriaServicio SET Nombre = @Nombre WHERE CategoriaID = @CategoriaID;
    SET IDENTITY_INSERT Servicios.CategoriaServicio OFF;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarSubcategoria
    @SubcategoriaID INT, @CategoriaID INT, @Nombre VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Servicios.SubcategoriaServicio ON;
    IF NOT EXISTS (SELECT 1 FROM Servicios.SubcategoriaServicio WHERE SubcategoriaID = @SubcategoriaID)
        INSERT INTO Servicios.SubcategoriaServicio (SubcategoriaID, CategoriaID, Nombre)
        VALUES (@SubcategoriaID, @CategoriaID, @Nombre);
    ELSE
        UPDATE Servicios.SubcategoriaServicio SET Nombre = @Nombre, CategoriaID = @CategoriaID
        WHERE SubcategoriaID = @SubcategoriaID;
    SET IDENTITY_INSERT Servicios.SubcategoriaServicio OFF;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarServicio
    @ServicioID INT, @Nombre VARCHAR(150), @DuracionMin INT,
    @SubcategoriaID INT, @Descripcion VARCHAR(255), @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Servicios.Servicio ON;
    IF NOT EXISTS (SELECT 1 FROM Servicios.Servicio WHERE ServicioID = @ServicioID)
        INSERT INTO Servicios.Servicio (ServicioID, Nombre, DuracionMin, SubcategoriaID, Descripcion, Activo)
        VALUES (@ServicioID, @Nombre, @DuracionMin, @SubcategoriaID, @Descripcion, @Activo);
    ELSE
        UPDATE Servicios.Servicio SET Nombre=@Nombre, DuracionMin=@DuracionMin,
            SubcategoriaID=@SubcategoriaID, Descripcion=@Descripcion, Activo=@Activo
        WHERE ServicioID = @ServicioID;
    SET IDENTITY_INSERT Servicios.Servicio OFF;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarPromocion
    @PromocionID INT, @Nombre VARCHAR(100), @Descripcion VARCHAR(255),
    @FechaInicio DATE, @FechaFin DATE, @Descuento DECIMAL(5,2),
    @Activo BIT, @TipoPromocion VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Marketing.Promocion ON;
    IF NOT EXISTS (SELECT 1 FROM Marketing.Promocion WHERE PromocionID = @PromocionID)
        INSERT INTO Marketing.Promocion (PromocionID, Nombre, Descripcion, FechaInicio, FechaFin, Descuento, Activo, TipoPromocion)
        VALUES (@PromocionID, @Nombre, @Descripcion, @FechaInicio, @FechaFin, @Descuento, @Activo, @TipoPromocion);
    ELSE
        UPDATE Marketing.Promocion SET Nombre=@Nombre, Descripcion=@Descripcion, FechaInicio=@FechaInicio,
            FechaFin=@FechaFin, Descuento=@Descuento, Activo=@Activo, TipoPromocion=@TipoPromocion
        WHERE PromocionID = @PromocionID;
    SET IDENTITY_INSERT Marketing.Promocion OFF;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarProducto
    @ProductoID INT, @Nombre VARCHAR(100), @StockActual INT,
    @StockMinimo INT, @UnidadMedida VARCHAR(20), @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Inventario.Producto ON;
    IF NOT EXISTS (SELECT 1 FROM Inventario.Producto WHERE ProductoID = @ProductoID)
        INSERT INTO Inventario.Producto (ProductoID, Nombre, StockActual, StockMinimo, UnidadMedida, Activo)
        VALUES (@ProductoID, @Nombre, @StockActual, @StockMinimo, @UnidadMedida, @Activo);
    ELSE
        UPDATE Inventario.Producto SET Nombre=@Nombre, StockActual=@StockActual,
            StockMinimo=@StockMinimo, UnidadMedida=@UnidadMedida, Activo=@Activo
        WHERE ProductoID = @ProductoID;
    SET IDENTITY_INSERT Inventario.Producto OFF;
END;
GO

-- ── Datos iniciales del catálogo ─────────────────────────────

-- Roles de seguridad
INSERT INTO Seguridad.Rol (Nombre) VALUES
('Dueno/a'), ('Administrador'), ('Cliente'),
('Atencion y soporte'), ('Personal tecnico');
GO

-- Roles laborales
INSERT INTO RRHH.Rol (NombreRol) VALUES
('Administrador'), ('Estilista'), ('Colorista'),
('Manicurista / Pedicurista'), ('Maquillador/a'), ('Recepcionista');
GO

-- Metodos de pago
INSERT INTO Ventas.MetodoPago (Nombre) VALUES
('Efectivo'), ('Tarjeta de debito'), ('Tarjeta de credito'), ('QR / Transferencia');
GO

-- Estados de cita
SET IDENTITY_INSERT Agenda.EstadoCita ON;
INSERT INTO Agenda.EstadoCita (EstadoID, Nombre) VALUES
(8,'Programada'),(9,'Confirmada'),(10,'En curso'),
(11,'Completada'),(12,'Cancelada'),(13,'No asistio');
SET IDENTITY_INSERT Agenda.EstadoCita OFF;
GO

-- Tipos de notificacion
INSERT INTO Notificaciones.TipoNotificacion (Nombre) VALUES
('recordatorio_cita'),('bienvenida'),('stock_minimo'),
('actualizacion_sueldo'),('aprobacion_excepcion'),
('nuevo_cliente'),('cancelacion_cita');
GO

SET IDENTITY_INSERT Notificaciones.TipoNotificacion ON;
IF NOT EXISTS (SELECT 1 FROM Notificaciones.TipoNotificacion WHERE TipoNotificacionID = 8)
    INSERT INTO Notificaciones.TipoNotificacion (TipoNotificacionID, Nombre) VALUES (8, 'solicitud_aprobada');
IF NOT EXISTS (SELECT 1 FROM Notificaciones.TipoNotificacion WHERE TipoNotificacionID = 9)
    INSERT INTO Notificaciones.TipoNotificacion (TipoNotificacionID, Nombre) VALUES (9, 'solicitud_rechazada');
SET IDENTITY_INSERT Notificaciones.TipoNotificacion OFF;
GO

PRINT 'CBB_02_datos.sql ejecutado correctamente';
GO