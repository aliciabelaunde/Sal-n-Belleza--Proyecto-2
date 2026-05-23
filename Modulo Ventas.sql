USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO VENTAS
-- Ventas.MetodoPago           → REPLICADA
-- Ventas.Cliente              → FRAGMENTADA
-- Ventas.ClienteDetalle       → FRAGMENTADA
-- Ventas.Venta                → FRAGMENTADA
-- Ventas.VentaDetalleProducto → FRAGMENTADA
-- Ventas.VentaDetalleServicio → FRAGMENTADA
-- Ventas.Pago                 → FRAGMENTADA
-- ============================================================

CREATE TABLE Ventas.MetodoPago (
    MetodoPagoID INT         IDENTITY PRIMARY KEY,
    Nombre       VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Ventas.Cliente (
    ClienteID INT     PRIMARY KEY,
    Sucursal  CHAR(3) NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (ClienteID) REFERENCES Personas.Persona(PersonaID)
);
GO

CREATE TABLE Ventas.ClienteDetalle (
    ClienteID          INT PRIMARY KEY,
    Alergias           VARCHAR(MAX),
    Contraindicaciones VARCHAR(MAX),
    NotasTecnicas      VARCHAR(MAX),
    FOREIGN KEY (ClienteID) REFERENCES Ventas.Cliente(ClienteID)
);
GO

CREATE TABLE Ventas.Venta (
    VentaID         INT           IDENTITY PRIMARY KEY,
    ClienteID       INT           NOT NULL,
    EmpleadoID      INT           NULL,
    Fecha           DATETIME      NOT NULL DEFAULT GETDATE(),
    Estado          VARCHAR(20)   NOT NULL DEFAULT 'pendiente'
                    CHECK (Estado IN ('pendiente','pagado','cancelado')),
    DescuentoPct    DECIMAL(5,2)  NULL DEFAULT 0,
    DescuentoMonto  DECIMAL(10,2) NULL DEFAULT 0,
    PromocionID     INT           NULL,
    Sucursal        CHAR(3)       NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (ClienteID)  REFERENCES Ventas.Cliente(ClienteID),
    FOREIGN KEY (EmpleadoID) REFERENCES RRHH.Empleado(EmpleadoID)
);
GO

CREATE TABLE Ventas.VentaDetalleProducto (
    VentaDetalleProductoID INT           IDENTITY PRIMARY KEY,
    VentaID                INT           NOT NULL,
    ProductoID             INT           NOT NULL,
    Cantidad               INT           NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario         DECIMAL(10,2) NOT NULL CHECK (PrecioUnitario > 0),
    Sucursal               CHAR(3)       NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (VentaID)    REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (ProductoID) REFERENCES Inventario.Producto(ProductoID)
);
GO

CREATE TABLE Ventas.VentaDetalleServicio (
    VentaDetalleServicioID INT           IDENTITY PRIMARY KEY,
    VentaID                INT           NOT NULL,
    ServicioID             INT           NOT NULL,
    Cantidad               INT           NOT NULL CHECK (Cantidad > 0),
    PrecioUnitario         DECIMAL(10,2) NOT NULL CHECK (PrecioUnitario > 0),
    EmpleadoID             INT           NULL,
    Sucursal               CHAR(3)       NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (VentaID)    REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID)
);
GO

CREATE TABLE Ventas.Pago (
    PagoID       INT           IDENTITY PRIMARY KEY,
    VentaID      INT           NOT NULL,
    MetodoPagoID INT           NOT NULL,
    Monto        DECIMAL(10,2) NOT NULL CHECK (Monto > 0),
    Fecha        DATETIME      NOT NULL DEFAULT GETDATE(),
    Sucursal     CHAR(3)       NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (VentaID)      REFERENCES Ventas.Venta(VentaID),
    FOREIGN KEY (MetodoPagoID) REFERENCES Ventas.MetodoPago(MetodoPagoID)
);
GO