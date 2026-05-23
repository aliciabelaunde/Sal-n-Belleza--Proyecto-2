
---------------------------------------------------------
--SINCRONIZACION DE TABLAS
---------------------------------------------------------
USE SalonBelleza_CBB;
GO

CREATE OR ALTER PROCEDURE dbo.SP_InsertarServicio
    @ServicioID INT, @Nombre VARCHAR(150), @DuracionMin INT,
    @SubcategoriaID INT, @Descripcion VARCHAR(255), @Activo BIT
AS
BEGIN
    SET NOCOUNT ON;
    SET IDENTITY_INSERT Servicios.Servicio ON;
    IF EXISTS (SELECT 1 FROM Servicios.Servicio WHERE ServicioID = @ServicioID)
        UPDATE Servicios.Servicio SET
            Nombre = @Nombre, DuracionMin = @DuracionMin,
            SubcategoriaID = @SubcategoriaID, Descripcion = @Descripcion, Activo = @Activo
        WHERE ServicioID = @ServicioID;
    ELSE
        INSERT INTO Servicios.Servicio (ServicioID, Nombre, DuracionMin, SubcategoriaID, Descripcion, Activo)
        VALUES (@ServicioID, @Nombre, @DuracionMin, @SubcategoriaID, @Descripcion, @Activo);
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
    IF EXISTS (SELECT 1 FROM Marketing.Promocion WHERE PromocionID = @PromocionID)
        UPDATE Marketing.Promocion SET
            Nombre = @Nombre, Descripcion = @Descripcion, FechaInicio = @FechaInicio,
            FechaFin = @FechaFin, Descuento = @Descuento, Activo = @Activo, TipoPromocion = @TipoPromocion
        WHERE PromocionID = @PromocionID;
    ELSE
        INSERT INTO Marketing.Promocion (PromocionID, Nombre, Descripcion, FechaInicio, FechaFin, Descuento, Activo, TipoPromocion)
        VALUES (@PromocionID, @Nombre, @Descripcion, @FechaInicio, @FechaFin, @Descuento, @Activo, @TipoPromocion);
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
    IF EXISTS (SELECT 1 FROM Inventario.Producto WHERE ProductoID = @ProductoID)
        UPDATE Inventario.Producto SET
            Nombre = @Nombre, StockActual = @StockActual,
            StockMinimo = @StockMinimo, UnidadMedida = @UnidadMedida, Activo = @Activo
        WHERE ProductoID = @ProductoID;
    ELSE
        INSERT INTO Inventario.Producto (ProductoID, Nombre, StockActual, StockMinimo, UnidadMedida, Activo)
        VALUES (@ProductoID, @Nombre, @StockActual, @StockMinimo, @UnidadMedida, @Activo);
    SET IDENTITY_INSERT Inventario.Producto OFF;
END;
GO