USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO INVENTARIO · REPLICADA
-- ============================================================

CREATE TABLE Inventario.Proveedor (
    ProveedorID INT          IDENTITY PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL,
    Telefono    VARCHAR(20),
    Email       VARCHAR(100),
    Activo      BIT          NOT NULL DEFAULT 1
);
GO

CREATE TABLE Inventario.Producto (
    ProductoID   INT          IDENTITY PRIMARY KEY,
    Nombre       VARCHAR(100) NOT NULL,
    StockActual  INT          NOT NULL DEFAULT 0 CHECK (StockActual >= 0),
    StockMinimo  INT          NOT NULL DEFAULT 0,
    UnidadMedida VARCHAR(20)  NOT NULL,
    Activo       BIT          NOT NULL DEFAULT 1
);
GO

CREATE TABLE Inventario.ProductoProveedor (
    ProductoID  INT NOT NULL,
    ProveedorID INT NOT NULL,
    PRIMARY KEY (ProductoID, ProveedorID),
    FOREIGN KEY (ProductoID)  REFERENCES Inventario.Producto(ProductoID),
    FOREIGN KEY (ProveedorID) REFERENCES Inventario.Proveedor(ProveedorID)
);
GO

CREATE TABLE Inventario.ProductoPrecio (
    ProductoPrecioID INT           IDENTITY PRIMARY KEY,
    ProductoID       INT           NOT NULL,
    Precio           DECIMAL(10,2) NOT NULL CHECK (Precio > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);
GO

CREATE TABLE Inventario.MovimientoInventario (
    MovimientoID INT      IDENTITY PRIMARY KEY,
    ProductoID   INT      NOT NULL,
    EsEntrada    BIT      NOT NULL,
    Cantidad     INT      NOT NULL CHECK (Cantidad > 0),
    Fecha        DATETIME NOT NULL DEFAULT GETDATE(),
    Sucursal     CHAR(3)  NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID)
);
GO