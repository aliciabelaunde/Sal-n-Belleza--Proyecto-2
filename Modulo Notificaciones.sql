USE SalonBelleza_CBB;
GO
-- ============================================================
-- MÓDULO NOTIFICACIONES
-- Notificaciones.TipoNotificacion → REPLICADA
-- Notificaciones.Notificacion     → FRAGMENTADA
-- ============================================================

CREATE TABLE Notificaciones.TipoNotificacion (
    TipoNotificacionID INT         IDENTITY PRIMARY KEY,
    Nombre             VARCHAR(50) NOT NULL UNIQUE
);
GO

CREATE TABLE Notificaciones.Notificacion (
    NotificacionID     INT          IDENTITY PRIMARY KEY,
    PersonaID          INT          NOT NULL,
    TipoNotificacionID INT          NOT NULL,
    Mensaje            VARCHAR(500) NOT NULL,
    Fecha              DATETIME     NOT NULL DEFAULT GETDATE(),
    Leido              BIT          NOT NULL DEFAULT 0,
    Sucursal           CHAR(3)      NOT NULL DEFAULT 'CBB',
    FOREIGN KEY (PersonaID)          REFERENCES Personas.Persona(PersonaID),
    FOREIGN KEY (TipoNotificacionID) REFERENCES Notificaciones.TipoNotificacion(TipoNotificacionID)
);
GO
