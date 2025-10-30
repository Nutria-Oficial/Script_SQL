-------------------------------------------- R E S E T -----------------------------------------------------------------
DROP VIEW IF EXISTS view_stats_rpa;
DROP VIEW IF EXISTS view_idade;

DROP TABLE IF EXISTS admin CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS log_rpa;
------------------------------------------------------------------------------------------------------------------------



-------------------------------------------- T A B E L A S -------------------------------------------------------------
------ Criação da tabela usuario ---------------------------------------------------------------------------------------
CREATE TABLE usuario (
  nCdUsuario SERIAL PRIMARY KEY,
  cNmUsuario VARCHAR(100) NOT NULL,
  cEmail     VARCHAR(100) NOT NULL UNIQUE,
  cSenha     VARCHAR(255) NOT NULL CHECK (LENGTH(cSenha) >= 8),
  cTelefone  VARCHAR(11) NOT NULL UNIQUE CHECK (LENGTH(cTelefone) = 11),
  cEmpresa   VARCHAR(50) DEFAULT 'Empresa não informada',
  cFoto      VARCHAR(255) DEFAULT 'Sem foto'
);
------ Criação da tabela admin -----------------------------------------------------------------------------------------
CREATE TABLE admin(
    nCdAdmin    SERIAL PRIMARY KEY,
    cNmAdmin    VARCHAR(100) NOT NULL,
    cEmail      VARCHAR(320) NOT NULL UNIQUE,
    cSenha      VARCHAR(255)  NOT NULL CHECK (LENGTH(cSenha) >= 8),
    cTelefone   VARCHAR(11) NOT NULL UNIQUE CHECK (LENGTH(cTelefone) = 11),
    dNascimento DATE NOT NULL,
    cCargo      VARCHAR(64) NOT NULL DEFAULT 'Admin',
    cFoto       VARCHAR(255) DEFAULT 'Sem foto'
);
------- Criação da tabela log_admin ------------------------------------------------------------------------------------
CREATE TABLE log_admin (
  nCdLog          SERIAL PRIMARY KEY,
  cTabelaAfetada  VARCHAR(100) NOT NULL,
  cOperacao       VARCHAR(10) NOT NULL,
  nCdAdminAfetado INT,
  cDadosAntigos   JSONB DEFAULT NULL,
  cDadosNovos     JSONB DEFAULT NULL,
  dHorario        TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,

  -- Se o admin for deletado, o ID ficará NULL, mas o log continua.
  CONSTRAINT fk_log_admin_ref_admin
    FOREIGN KEY (nCdAdminAfetado) REFERENCES admin(nCdAdmin)
    ON DELETE SET NULL
);
------- Criação da tabela log_usuario ----------------------------------------------------------------------------------
CREATE TABLE log_usuario (
  nCdLog            SERIAL PRIMARY KEY,
  cTabelaAfetada    VARCHAR(100) NOT NULL,
  cOperacao         VARCHAR(10) NOT NULL,
  nCdUsuarioAfetado INT,
  cDadosAntigos     JSONB DEFAULT NULL,
  cDadosNovos       JSONB DEFAULT NULL,
  tHorario          TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP,

  -- Se o usuário for deletado, o ID fica NULL, mas o log continua.
  CONSTRAINT fk_log_usuario_ref_usuario
    FOREIGN KEY (nCdUsuarioAfetado) REFERENCES usuario(nCdUsuario)
    ON DELETE SET NULL
);
------- Criação da tabela acesso_diario --------------------------------------------------------------------------------
CREATE TABLE acesso_diario (
    nCdAcesso   SERIAL PRIMARY KEY,
    nCdUsuario  INT,
    dDataAcesso DATE DEFAULT CURRENT_DATE,
  
    CONSTRAINT uq_usuario_data UNIQUE (nCdUsuario, dDataAcesso),
    CONSTRAINT fk_acesso_diario_ref_usuario
        FOREIGN KEY (nCdUsuario) REFERENCES usuario(nCdUsuario)
        ON DELETE SET NULL
);
------- Criação da tabela log_rpa --------------------------------------------------------------------------------------
CREATE TABLE log_rpa (
  nCdLog  SERIAL PRIMARY KEY,
  cStatus VARCHAR(7) NOT NULL,
  dDate   DATE NOT NULL,
  tTime   TIME NOT NULL,
  cText   VARCHAR(255) NOT NULL
);
------------------------------------------------------------------------------------------------------------------------



-------------------------------------------- F U N Ç Õ E S   C R U D S -------------------------------------------------
----------- Crud admins ------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_verificar_admin(Email VARCHAR(100))
RETURNS BOOLEAN AS $$
DECLARE
    admin_existe BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM admin WHERE cEmail = Email) INTO admin_existe;
    RETURN admin_existe;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE proc_adicionar_admin(Admin VARCHAR(100), Email VARCHAR(100), Senha VARCHAR(64), Telefone VARCHAR(11), DataNascimento DATE
)
LANGUAGE plpgsql AS
$$
begin

    IF Admin IS NULL OR Email IS NULL OR Senha IS NULL OR Telefone IS NULL OR DataNascimento IS NULL THEN
        RAISE EXCEPTION 'Dados nulos não são permitidos (Admin, Email, Senha, Telefone, DataNascimento).';
    END IF;

    IF func_verificar_admin(Email) THEN
        RAISE EXCEPTION 'Falha na operação: Já existe esse administrador cadastrado.';
    END IF;

    INSERT INTO admin (cNmAdmin, cEmail, cSenha, cTelefone, dNascimento)
    VALUES (Admin, Email, Senha, Telefone, DataNascimento);

    RAISE NOTICE 'Inserção do Admin realizada com sucesso';

END;
$$;
CREATE OR REPLACE PROCEDURE proc_remover_admin(Email VARCHAR(100))
LANGUAGE plpgsql AS
$$
begin
    IF not func_verificar_admin(Email) THEN
        RAISE EXCEPTION 'O admin não está registrado no sistema, impossível remover.';
    END IF;

    DELETE FROM admin where cEmail = Email;
    RAISE NOTICE 'Admin removido com sucesso.';

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Falha ao remover o administrador: %', SQLERRM;
END;
$$;

----------- Crud usuarios ----------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_verificar_usuario(Email VARCHAR(100))
RETURNS BOOLEAN AS $$
DECLARE
    usuario_existe BOOLEAN;
BEGIN
    SELECT EXISTS (SELECT 1 FROM usuario WHERE cEmail = Email) INTO usuario_existe;
    RETURN usuario_existe;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE PROCEDURE proc_adicionar_usuario(
    Usuario VARCHAR(100), Email VARCHAR(100),
    Senha VARCHAR(64),Telefone VARCHAR(11),
    Empresa VARCHAR(255) DEFAULT NULL, Foto VARCHAR(255) DEFAULT NULL
)
LANGUAGE plpgsql AS
$$
begin
    IF Usuario IS NULL OR Email IS NULL OR Senha IS NULL OR Telefone IS NULL THEN
        RAISE EXCEPTION 'Os campos obrigatórios, não podem ser nulos.';
    END IF;

    IF func_verificar_usuario(Email) THEN
        RAISE EXCEPTION 'Falha na operação: Já existe um usuário cadastrado com o e-mail: %', Email;
    END IF;

    INSERT INTO usuario (cNmUsuario, cEmail, cSenha, cTelefone, cEmpresa, cFoto)
    VALUES (Usuario, Email, Senha, Telefone, Empresa, Foto);

    RAISE NOTICE 'Inserção realizada com sucesso';

END;
$$;
CREATE OR REPLACE PROCEDURE proc_remover_usuario(Email VARCHAR(100))
LANGUAGE plpgsql AS
$$
begin
    IF NOT func_verificar_usuario(Email) THEN
        RAISE EXCEPTION 'Usuário não consta no sistema, impossível remover.';
    END IF;
    DELETE FROM usuario WHERE cEmail = Email;
END;
$$;
------------------------------------------------------------------------------------------------------------------------



-------------------------------------------- F U N Ç Ã O  L O G I N ----------------------------------------------------
CREATE OR REPLACE FUNCTION func_autenticar_e_registrar_acesso(p_Email VARCHAR(100), p_Senha VARCHAR(64))
RETURNS INTEGER AS $$
DECLARE
    id_usuario INTEGER;
BEGIN
    BEGIN
        SELECT nCdUsuario INTO STRICT id_usuario
        FROM usuario
        WHERE cEmail = p_Email AND cSenha = p_Senha;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            id_usuario := NULL;
    END;

    IF id_usuario IS NOT NULL THEN
        INSERT INTO acesso_diario (nCdUsuario)
        VALUES (id_usuario)
        ON CONFLICT ON CONSTRAINT uq_usuario_data DO NOTHING;
    END IF;

    RETURN id_usuario;

END;
$$ LANGUAGE plpgsql;
------------------------------------------------------------------------------------------------------------------------



-------------------------------------------- F U N Ç Õ E S   T R I G G E R S -------------------------------------------
----------- Função de trigger para a tabela log_admin ------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_log_mudancas_admin()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO log_admin (cTabelaAfetada, cOperacao, nCdAdminAfetado, cDadosAntigos)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.nCdAdmin, row_to_json(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_admin (cTabelaAfetada, cOperacao, nCdAdminAfetado, cDadosAntigos, cDadosNovos)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.nCdAdmin, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO log_admin (cTabelaAfetada, cOperacao, nCdAdminAfetado, cDadosNovos)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.nCdAdmin, row_to_json(NEW)); -- <--- ERRO CORRIGIDO AQUI
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
----------- Função de trigger para a tabela log_usuario ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_log_mudancas_usuario()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO log_usuario (cTabelaAfetada, cOperacao, nCdUsuarioAfetado, cDadosAntigos)
        VALUES (TG_TABLE_NAME, TG_OP, OLD.nCdUsuario, row_to_json(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO log_usuario (cTabelaAfetada, cOperacao, nCdUsuarioAfetado, cDadosAntigos, cDadosNovos)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.nCdUsuario, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO log_usuario (cTabelaAfetada, cOperacao, nCdUsuarioAfetado, cDadosNovos)
        VALUES (TG_TABLE_NAME, TG_OP, NEW.nCdUsuario, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
----------- Função de trigger para o acesso_diario ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION func_registrar_acesso_diario()
RETURNS TRIGGER AS $$
BEGIN

    INSERT INTO acesso_diario (nCdUsuario)
    VALUES (NEW.nCdUsuario)
    ON CONFLICT ON CONSTRAINT uq_usuario_data DO NOTHING;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
------------------------------------------------------------------------------------------------------------------------



------------------------------------------- T R I G G E R S ------------------------------------------------------------
----------- Trigger para a tabela admin -------------------------------------------------------------------------------
CREATE TRIGGER tr_log_admin
AFTER INSERT OR UPDATE OR DELETE ON admin
FOR EACH ROW EXECUTE FUNCTION func_log_mudancas_admin();
----------- Trigger para a tabela usuario -----------------------------------------------------------------------------
CREATE TRIGGER tr_log_usuario
AFTER INSERT OR UPDATE OR DELETE ON usuario
FOR EACH ROW EXECUTE FUNCTION func_log_mudancas_usuario();
----------- Trigger para registrar o primeiro acesso -------------------------------------------------------------------
CREATE TRIGGER tr_registrar_acesso_usuario
AFTER INSERT ON usuario
FOR EACH ROW EXECUTE FUNCTION func_registrar_acesso_diario();
------------------------------------------------------------------------------------------------------------------------



------------------------------------------- V I E W S ------------------------------------------------------------------
----------- View para a tabela log_rpa ---------------------------------------------------------------------------------
CREATE OR REPLACE VIEW view_stats_rpa AS SELECT
    cStatus       AS Status,
    COUNT(nCdLog) AS Total_Ocorrencias,
    MIN(dDate)    AS Primeira_Ocorrencia,
    MAX(dDate)    AS Ultima_Ocorrencia
FROM log_rpa
WHERE cStatus IN ('INFO', 'WARNING', 'ERROR', 'SUCCESS')
GROUP BY cStatus;
----------- View para a tabela admin -----------------------------------------------------------------------------------
CREATE OR REPLACE VIEW view_idade AS SELECT cNmAdmin,
    EXTRACT(YEAR FROM AGE(dNascimento)) AS Idade_Anos
FROM ADMIN;
------------------------------------------------------------------------------------------------------------------------



------------------------------------------- Í N D I C E S --------------------------------------------------------------
-- Otimiza a busca pelo histórico de user ------------------------------------------------------------------------------
CREATE INDEX index_log_usuario_fk ON log_usuario(nCdUsuarioAfetado);
-- Otimiza a busca pelo histórico de admin -----------------------------------------------------------------------------
CREATE INDEX index_log_admin_fk ON log_admin(nCdAdminAfetado);
-- Otimiza a busca de acessos diários (DAU) de user --------------------------------------------------------------------
CREATE INDEX index_acesso_diario_fk ON acesso_diario(nCdUsuario);
------------------------------------------------------------------------------------------------------------------------

