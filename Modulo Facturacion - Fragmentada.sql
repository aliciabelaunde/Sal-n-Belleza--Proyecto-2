USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO FACTURACIÓN · FRAGMENTADA
-- ============================================================

CREATE TABLE Facturacion.Factura (
    FacturaID     INT          IDENTITY PRIMARY KEY,
    VentaID       INT          NOT NULL UNIQUE,
    NumeroFactura VARCHAR(50)  NOT NULL UNIQUE,
    Fecha         DATETIME     NOT NULL DEFAULT GETDATE(),
    Estado        VARCHAR(20)  NOT NULL DEFAULT 'emitida'
                  CHECK (Estado IN ('emitida','pagada','anulada')),
    Sucursal      CHAR(3)      NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (VentaID) REFERENCES Ventas.Venta(VentaID)
);
GO