-- =====================================================
-- E-commerce | Projeto lógico (MySQL 8.0.16+)
-- Parte 1: criação do esquema + persistência de dados de teste
-- Sem CREATE DATABASE/USE: pode ser colado direto no DB Fiddle
-- (painel de cima, "Schema SQL").
-- =====================================================

-- ---------- CLIENTE (supertipo) ----------
CREATE TABLE cliente (
    id_cliente    INT AUTO_INCREMENT PRIMARY KEY,
    tipo_cliente  CHAR(2) NOT NULL,                 -- discriminador: 'PF' ou 'PJ'
    email         VARCHAR(120) NOT NULL UNIQUE,
    telefone      VARCHAR(20),
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_tipo_cliente CHECK (tipo_cliente IN ('PF','PJ')),
    CONSTRAINT uq_cliente_tipo UNIQUE (id_cliente, tipo_cliente)
);

-- ---------- SUBTIPO PF ----------
CREATE TABLE cliente_pf (
    id_cliente      INT PRIMARY KEY,
    tipo_cliente    CHAR(2) NOT NULL DEFAULT 'PF',
    nome            VARCHAR(60) NOT NULL,
    sobrenome       VARCHAR(60) NOT NULL,
    cpf             CHAR(11) NOT NULL UNIQUE,
    data_nascimento DATE,
    CONSTRAINT chk_pf_tipo CHECK (tipo_cliente = 'PF'),
    CONSTRAINT fk_pf_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente)
);

-- ---------- SUBTIPO PJ ----------
CREATE TABLE cliente_pj (
    id_cliente         INT PRIMARY KEY,
    tipo_cliente       CHAR(2) NOT NULL DEFAULT 'PJ',
    razao_social       VARCHAR(120) NOT NULL,
    nome_fantasia      VARCHAR(120),
    cnpj               CHAR(14) NOT NULL UNIQUE,
    inscricao_estadual VARCHAR(20),
    CONSTRAINT chk_pj_tipo CHECK (tipo_cliente = 'PJ'),
    CONSTRAINT fk_pj_cliente FOREIGN KEY (id_cliente, tipo_cliente)
        REFERENCES cliente (id_cliente, tipo_cliente)
);

-- ---------- ENDEREÇO ----------
CREATE TABLE endereco (
    id_endereco INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente  INT NOT NULL,
    logradouro  VARCHAR(120) NOT NULL,
    numero      VARCHAR(10),
    bairro      VARCHAR(60),
    cidade      VARCHAR(60) NOT NULL,
    uf          CHAR(2) NOT NULL,
    cep         CHAR(8) NOT NULL,
    CONSTRAINT fk_end_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE CASCADE,
    CONSTRAINT uq_end_cliente UNIQUE (id_endereco, id_cliente)
);

-- ---------- FORMA DE PAGAMENTO (N por cliente) ----------
-- Nunca armazenar número completo/CVV: apenas dados não sensíveis.
CREATE TABLE forma_pagamento (
    id_forma_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente         INT NOT NULL,
    tipo               ENUM('CARTAO_CREDITO','CARTAO_DEBITO','PIX','BOLETO') NOT NULL,
    apelido            VARCHAR(40),
    bandeira           VARCHAR(20),
    ultimos_digitos    CHAR(4),
    chave_pix          VARCHAR(80),
    principal          BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_fp_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente)
        ON DELETE CASCADE,
    CONSTRAINT uq_fp_cliente UNIQUE (id_forma_pagamento, id_cliente)
);

-- ---------- FORNECEDOR / VENDEDOR (TERCEIRO) ----------
CREATE TABLE fornecedor (
    id_fornecedor INT AUTO_INCREMENT PRIMARY KEY,
    razao_social  VARCHAR(120) NOT NULL,
    cnpj          CHAR(14) NOT NULL UNIQUE,
    contato       VARCHAR(120)
);

CREATE TABLE vendedor (
    id_vendedor  INT AUTO_INCREMENT PRIMARY KEY,
    razao_social VARCHAR(120) NOT NULL,
    cnpj         CHAR(14) NOT NULL UNIQUE,
    cidade       VARCHAR(60)
);

-- ---------- PRODUTO / ESTOQUE ----------
CREATE TABLE produto (
    id_produto INT AUTO_INCREMENT PRIMARY KEY,
    nome       VARCHAR(100) NOT NULL,
    categoria  VARCHAR(40) NOT NULL,
    descricao  VARCHAR(255),
    valor      DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_prod_valor CHECK (valor > 0)
);

CREATE TABLE local_estoque (
    id_local  INT AUTO_INCREMENT PRIMARY KEY,
    descricao VARCHAR(80) NOT NULL,
    cidade    VARCHAR(60) NOT NULL
);

-- N:M produto x local de estoque
CREATE TABLE produto_estoque (
    id_produto INT NOT NULL,
    id_local   INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_produto, id_local),
    CONSTRAINT chk_pe_qtd CHECK (quantidade >= 0),
    CONSTRAINT fk_pe_produto FOREIGN KEY (id_produto) REFERENCES produto (id_produto),
    CONSTRAINT fk_pe_local   FOREIGN KEY (id_local)   REFERENCES local_estoque (id_local)
);

-- N:M produto x fornecedor
CREATE TABLE produto_fornecedor (
    id_produto    INT NOT NULL,
    id_fornecedor INT NOT NULL,
    preco_custo   DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_produto, id_fornecedor),
    CONSTRAINT fk_pfo_produto    FOREIGN KEY (id_produto)    REFERENCES produto (id_produto),
    CONSTRAINT fk_pfo_fornecedor FOREIGN KEY (id_fornecedor) REFERENCES fornecedor (id_fornecedor)
);

-- N:M produto x vendedor terceiro
CREATE TABLE produto_vendedor (
    id_produto  INT NOT NULL,
    id_vendedor INT NOT NULL,
    quantidade  INT NOT NULL DEFAULT 0,
    preco_venda DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_produto, id_vendedor),
    CONSTRAINT fk_pv_produto  FOREIGN KEY (id_produto)  REFERENCES produto (id_produto),
    CONSTRAINT fk_pv_vendedor FOREIGN KEY (id_vendedor) REFERENCES vendedor (id_vendedor)
);

-- ---------- PEDIDO ----------
CREATE TABLE pedido (
    id_pedido     INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente    INT NOT NULL,
    id_endereco   INT NOT NULL,
    status_pedido ENUM('ABERTO','AGUARDANDO_PAGAMENTO','PAGO','CANCELADO') NOT NULL DEFAULT 'ABERTO',
    frete         DECIMAL(10,2) NOT NULL DEFAULT 0,
    data_pedido   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ped_cliente FOREIGN KEY (id_cliente) REFERENCES cliente (id_cliente),
    -- o endereço de entrega precisa pertencer ao mesmo cliente do pedido
    CONSTRAINT fk_ped_endereco FOREIGN KEY (id_endereco, id_cliente)
        REFERENCES endereco (id_endereco, id_cliente),
    CONSTRAINT uq_ped_cliente UNIQUE (id_pedido, id_cliente)
);

CREATE TABLE item_pedido (
    id_pedido      INT NOT NULL,
    id_produto     INT NOT NULL,
    quantidade     INT NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,          -- preço congelado na compra
    PRIMARY KEY (id_pedido, id_produto),
    CONSTRAINT chk_item_qtd CHECK (quantidade > 0),
    CONSTRAINT fk_item_pedido  FOREIGN KEY (id_pedido)  REFERENCES pedido (id_pedido) ON DELETE CASCADE,
    CONSTRAINT fk_item_produto FOREIGN KEY (id_produto) REFERENCES produto (id_produto)
);

-- ---------- PAGAMENTO DO PEDIDO (permite dividir em várias formas) ----------
CREATE TABLE pedido_pagamento (
    id_pedido_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido           INT NOT NULL,
    id_cliente          INT NOT NULL,
    id_forma_pagamento  INT NOT NULL,
    valor               DECIMAL(10,2) NOT NULL,
    parcelas            TINYINT NOT NULL DEFAULT 1,
    status_pagamento    ENUM('PENDENTE','APROVADO','RECUSADO','ESTORNADO') NOT NULL DEFAULT 'PENDENTE',
    CONSTRAINT chk_pp_valor CHECK (valor > 0),
    -- pedido e forma de pagamento precisam ser do MESMO cliente
    CONSTRAINT fk_pp_pedido FOREIGN KEY (id_pedido, id_cliente)
        REFERENCES pedido (id_pedido, id_cliente),
    CONSTRAINT fk_pp_forma FOREIGN KEY (id_forma_pagamento, id_cliente)
        REFERENCES forma_pagamento (id_forma_pagamento, id_cliente)
);

-- ---------- ENTREGA (status + código de rastreio) ----------
CREATE TABLE entrega (
    id_entrega      INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido       INT NOT NULL,
    transportadora  VARCHAR(60),
    codigo_rastreio VARCHAR(30) UNIQUE,             -- NULL até a postagem
    status_entrega  ENUM('AGUARDANDO_ENVIO','EM_SEPARACAO','POSTADO','EM_TRANSITO',
                         'SAIU_PARA_ENTREGA','ENTREGUE','DEVOLVIDO','CANCELADA')
                    NOT NULL DEFAULT 'AGUARDANDO_ENVIO',
    data_envio      DATETIME,
    data_previsao   DATE,
    data_entrega    DATETIME,
    CONSTRAINT fk_ent_pedido FOREIGN KEY (id_pedido) REFERENCES pedido (id_pedido),
    -- após a postagem, o código de rastreio é obrigatório
    CONSTRAINT chk_ent_rastreio CHECK (
        status_entrega IN ('AGUARDANDO_ENVIO','EM_SEPARACAO','CANCELADA')
        OR codigo_rastreio IS NOT NULL
    )
);

CREATE TABLE entrega_historico (
    id_evento      INT AUTO_INCREMENT PRIMARY KEY,
    id_entrega     INT NOT NULL,
    status_entrega VARCHAR(20) NOT NULL,
    localizacao    VARCHAR(100),
    data_evento    DATETIME NOT NULL,
    CONSTRAINT fk_hist_entrega FOREIGN KEY (id_entrega) REFERENCES entrega (id_entrega)
        ON DELETE CASCADE
);

-- =====================================================
-- PERSISTÊNCIA DE DADOS PARA TESTES
-- =====================================================

-- Clientes: 3 PF e 2 PJ (cada um em apenas UMA tabela de subtipo)
INSERT INTO cliente (id_cliente, tipo_cliente, email, telefone, data_cadastro) VALUES
 (1,'PF','ana@email.com','46999990001','2026-08-01 10:00:00'),
 (2,'PF','bruno@email.com','46999990002','2026-08-05 14:30:00'),
 (3,'PJ','contato@oficinasilva.com','4633330003','2026-08-10 09:15:00'),
 (4,'PJ','compras@mercadocentral.com','4633330004','2026-08-12 16:45:00'),
 (5,'PF','carla@email.com','46999990005','2026-09-01 11:20:00');

INSERT INTO cliente_pf (id_cliente, nome, sobrenome, cpf, data_nascimento) VALUES
 (1,'Ana','Souza','11111111111','1995-03-12'),
 (2,'Bruno','Lima','22222222222','1988-07-25'),
 (5,'Carla','Dias','33333333333','2001-11-02');

INSERT INTO cliente_pj (id_cliente, razao_social, nome_fantasia, cnpj, inscricao_estadual) VALUES
 (3,'Oficina Silva LTDA','Oficina Silva','11222333000144','123456789'),
 (4,'Mercado Central LTDA','Mercado Central','55666777000188','987654321');

INSERT INTO endereco (id_endereco, id_cliente, logradouro, numero, bairro, cidade, uf, cep) VALUES
 (1,1,'Rua das Flores','100','Centro','Laranjeiras do Sul','PR','85301000'),
 (2,2,'Rua XV de Novembro','250','Centro','Curitiba','PR','80020000'),
 (3,3,'Av. Industrial','500','Distrito Industrial','Londrina','PR','86000000'),
 (4,4,'Rua do Comércio','75','Centro','Cascavel','PR','85800000'),
 (5,1,'Rua das Acácias','45','Jardim','Guarapuava','PR','85010000');

-- Formas de pagamento: clientes com mais de uma forma cadastrada (cliente 5 não tem nenhuma)
INSERT INTO forma_pagamento (id_forma_pagamento, id_cliente, tipo, apelido, bandeira, ultimos_digitos, principal) VALUES
 (1,1,'CARTAO_CREDITO','Cartão principal','Mastercard','1234',TRUE),
 (3,2,'CARTAO_DEBITO','Débito Banco A','Visa','5678',TRUE),
 (5,3,'CARTAO_CREDITO','Cartão empresa','Visa','9012',FALSE);
INSERT INTO forma_pagamento (id_forma_pagamento, id_cliente, tipo, apelido, chave_pix, principal) VALUES
 (2,1,'PIX','Pix CPF','11111111111',FALSE),
 (4,3,'BOLETO','Boleto empresa',NULL,TRUE),
 (6,4,'PIX','Pix CNPJ','55666777000188',TRUE);

INSERT INTO fornecedor (id_fornecedor, razao_social, cnpj, contato) VALUES
 (1,'Eletrônicos Brasil LTDA','10101010000101','vendas@eletronicosbrasil.com'),
 (2,'Casa dos Cabos e Sensores LTDA','20202020000102','contato@casadoscabos.com'),
 (3,'Maker Supply Distribuidora LTDA','99888777000166','comercial@makersupply.com');

-- O vendedor 1 tem o MESMO CNPJ do fornecedor 3 (vendedor que também é fornecedor)
INSERT INTO vendedor (id_vendedor, razao_social, cnpj, cidade) VALUES
 (1,'Maker Supply Distribuidora LTDA','99888777000166','Curitiba'),
 (2,'Loja Maker Express ME','44333222000111','Londrina');

INSERT INTO produto (id_produto, nome, categoria, descricao, valor) VALUES
 (1,'ESP32-C3 Mini','Eletrônicos','Placa de desenvolvimento com Wi-Fi e Bluetooth',39.90),
 (2,'Servo SG90','Eletrônicos','Micro servo 9g',12.50),
 (3,'Sensor DHT22','Sensores','Temperatura e umidade',29.90),
 (4,'Kit Jumpers 40 fios','Acessórios','Macho-macho, macho-fêmea e fêmea-fêmea',15.00),
 (5,'Display OLED 0.96"','Eletrônicos','I2C, 128x64',34.90),
 (6,'Filamento PLA 1kg','Impressão 3D','Filamento 1,75 mm',89.90);

INSERT INTO local_estoque (id_local, descricao, cidade) VALUES
 (1,'Depósito Central','Curitiba'),
 (2,'Depósito Norte','Londrina');

INSERT INTO produto_estoque (id_produto, id_local, quantidade) VALUES
 (1,1,50),(1,2,20),(2,1,100),(3,1,5),(3,2,0),(4,1,200),(5,2,15),(6,1,8);

INSERT INTO produto_fornecedor (id_produto, id_fornecedor, preco_custo) VALUES
 (1,1,28.00),(2,1,8.00),(3,2,20.00),(4,2,9.00),(5,1,24.00),(6,3,65.00);

INSERT INTO produto_vendedor (id_produto, id_vendedor, quantidade, preco_venda) VALUES
 (1,1,30,41.90),(6,1,10,92.00),(2,2,60,13.00),(3,2,25,31.50),(4,2,100,15.50),(5,2,12,36.00);

INSERT INTO pedido (id_pedido, id_cliente, id_endereco, status_pedido, frete, data_pedido) VALUES
 (1,1,1,'PAGO',15.00,'2026-09-05 10:00:00'),
 (2,1,5,'PAGO',20.00,'2026-09-20 15:10:00'),
 (3,2,2,'PAGO',12.00,'2026-09-22 09:40:00'),
 (4,3,3,'AGUARDANDO_PAGAMENTO',30.00,'2026-10-02 13:25:00'),
 (5,4,4,'PAGO',0.00,'2026-10-10 08:55:00'),
 (6,1,1,'CANCELADO',15.00,'2026-10-15 17:30:00');

INSERT INTO item_pedido (id_pedido, id_produto, quantidade, preco_unitario) VALUES
 (1,1,2,39.90),(1,2,4,12.50),
 (2,6,1,89.90),
 (3,3,2,29.90),(3,4,1,15.00),
 (4,1,10,39.90),(4,5,5,34.90),
 (5,2,50,12.50),(5,4,20,15.00),
 (6,5,1,34.90);

-- Pedido 1 pago com DUAS formas (cartão + pix)
INSERT INTO pedido_pagamento (id_pedido, id_cliente, id_forma_pagamento, valor, parcelas, status_pagamento) VALUES
 (1,1,1,100.00,2,'APROVADO'),
 (1,1,2, 44.80,1,'APROVADO'),
 (2,1,2,109.90,1,'APROVADO'),
 (3,2,3, 86.80,1,'APROVADO'),
 (4,3,4,603.50,1,'PENDENTE'),
 (5,4,6,925.00,1,'APROVADO'),
 (6,1,1, 49.90,1,'ESTORNADO');

INSERT INTO entrega (id_entrega, id_pedido, transportadora, codigo_rastreio, status_entrega, data_envio, data_previsao, data_entrega) VALUES
 (1,1,'Correios','BR100000001BR','ENTREGUE','2026-09-06 09:00:00','2026-09-12','2026-09-11 14:20:00'),
 (2,2,'Jadlog','JD200000002','EM_TRANSITO','2026-09-21 10:00:00','2026-09-27',NULL),
 (3,3,'Correios','BR300000003BR','SAIU_PARA_ENTREGA','2026-09-23 08:30:00','2026-09-26',NULL),
 (4,4,NULL,NULL,'AGUARDANDO_ENVIO',NULL,NULL,NULL),
 (5,5,'Rápido Sul','RS500000005','POSTADO','2026-10-11 11:00:00','2026-10-18',NULL),
 (6,6,NULL,NULL,'CANCELADA',NULL,NULL,NULL);

INSERT INTO entrega_historico (id_entrega, status_entrega, localizacao, data_evento) VALUES
 (1,'POSTADO','Curitiba - PR','2026-09-06 09:00:00'),
 (1,'EM_TRANSITO','Ponta Grossa - PR','2026-09-08 07:45:00'),
 (1,'ENTREGUE','Laranjeiras do Sul - PR','2026-09-11 14:20:00'),
 (2,'POSTADO','Londrina - PR','2026-09-21 10:00:00'),
 (2,'EM_TRANSITO','Guarapuava - PR','2026-09-24 06:30:00');
