USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO MARKETING · REPLICADA
-- ============================================================

CREATE TABLE Marketing.Promocion (
    PromocionID   INT           IDENTITY PRIMARY KEY,
    Nombre        VARCHAR(100)  NOT NULL,
    Descripcion   VARCHAR(255)  NOT NULL,
    FechaInicio   DATE          NOT NULL,
    FechaFin      DATE          NOT NULL,
    Descuento     DECIMAL(5,2)  NOT NULL CHECK (Descuento > 0 AND Descuento <= 100),
    Activo        BIT           NOT NULL DEFAULT 1,
    TipoPromocion VARCHAR(20)   NULL DEFAULT 'general',
    CHECK (FechaFin > FechaInicio)
);
GO

CREATE TABLE Marketing.PromocionServicio (
    PromocionServicioID INT  IDENTITY PRIMARY KEY,
    PromocionID         INT  NOT NULL,
    ServicioID          INT  NOT NULL,
    FOREIGN KEY (PromocionID) REFERENCES Marketing.Promocion(PromocionID),
    FOREIGN KEY (ServicioID)  REFERENCES Servicios.Servicio(ServicioID)
);
GO