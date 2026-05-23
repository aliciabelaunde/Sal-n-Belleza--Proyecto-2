USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO SERVICIOS · REPLICADA
-- ============================================================

CREATE TABLE Servicios.CategoriaServicio (
    CategoriaID INT          IDENTITY PRIMARY KEY,
    Nombre      VARCHAR(100) NOT NULL UNIQUE
);
GO

CREATE TABLE Servicios.SubcategoriaServicio (
    SubcategoriaID INT          IDENTITY PRIMARY KEY,
    CategoriaID    INT          NOT NULL,
    Nombre         VARCHAR(100) NOT NULL,
    FOREIGN KEY (CategoriaID) REFERENCES Servicios.CategoriaServicio(CategoriaID)
);
GO

CREATE TABLE Servicios.SubcategoriaRol (
    SubcategoriaID INT NOT NULL,
    RolID          INT NOT NULL,
    PRIMARY KEY (SubcategoriaID, RolID),
    FOREIGN KEY (SubcategoriaID) REFERENCES Servicios.SubcategoriaServicio(SubcategoriaID),
    FOREIGN KEY (RolID)          REFERENCES RRHH.Rol(RolID)
);
GO

CREATE TABLE Servicios.Servicio (
    ServicioID     INT          IDENTITY PRIMARY KEY,
    Nombre         VARCHAR(150) NOT NULL UNIQUE,
    DuracionMin    INT          NOT NULL CHECK (DuracionMin > 0),
    SubcategoriaID INT          NOT NULL,
    Descripcion    VARCHAR(255) NOT NULL,
    Activo         BIT          NOT NULL DEFAULT 1,
    FOREIGN KEY (SubcategoriaID) REFERENCES Servicios.SubcategoriaServicio(SubcategoriaID)
);
GO

CREATE TABLE Servicios.ServicioPrecio (
    ServicioPrecioID INT           IDENTITY PRIMARY KEY,
    ServicioID       INT           NOT NULL,
    Precio           DECIMAL(10,2) NOT NULL CHECK (Precio > 0),
    FechaInicio      DATE          NOT NULL,
    FechaFin         DATE          NULL,
    FOREIGN KEY (ServicioID) REFERENCES Servicios.Servicio(ServicioID),
    CHECK (FechaFin IS NULL OR FechaFin > FechaInicio)
);
GO