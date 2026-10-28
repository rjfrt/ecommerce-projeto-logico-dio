-- =====================================================
-- E-commerce | Parte 2: queries
-- Execute UMA query por vez (no DB Fiddle, painel de baixo "Query SQL").
-- Cada query traz a pergunta de negócio que ela responde e as
-- cláusulas usadas.
-- =====================================================


-- Q1. Quais produtos existem no catálogo?
-- [SELECT simples]
SELECT id_produto, nome, categoria, valor
FROM produto;


-- Q2. Quais produtos de Eletrônicos custam mais de R$ 30,00?
-- [WHERE, ORDER BY]
SELECT nome, categoria, valor
FROM produto
WHERE categoria = 'Eletrônicos' AND valor > 30
ORDER BY valor DESC;


-- Q3. Qual a idade atual dos clientes pessoa física?
-- [atributo derivado (TIMESTAMPDIFF), ORDER BY]
SELECT CONCAT(nome, ' ', sobrenome) AS cliente,
       data_nascimento,
       TIMESTAMPDIFF(YEAR, data_nascimento, CURDATE()) AS idade
FROM cliente_pf
ORDER BY idade DESC;


-- Q4. Quem são os clientes (PF ou PJ) e qual o documento de cada um?
-- [atributo derivado (COALESCE/CASE), JUNÇÃO (LEFT JOIN nos dois subtipos)]
SELECT c.id_cliente,
       CASE c.tipo_cliente WHEN 'PF' THEN 'Pessoa Física' ELSE 'Pessoa Jurídica' END AS tipo,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       COALESCE(pf.cpf, pj.cnpj) AS documento
FROM cliente c
LEFT JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = c.id_cliente
ORDER BY c.id_cliente;


-- Q5. Quantos pedidos foram feitos por cada cliente (inclusive quem nunca comprou)?
-- [LEFT JOIN, GROUP BY, ORDER BY]
SELECT c.id_cliente,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       COUNT(p.id_pedido) AS qtd_pedidos
FROM cliente c
LEFT JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = c.id_cliente
LEFT JOIN pedido p      ON p.id_cliente  = c.id_cliente
GROUP BY c.id_cliente, pf.nome, pf.sobrenome, pj.razao_social
ORDER BY qtd_pedidos DESC, cliente;


-- Q6. Quais clientes fizeram mais de um pedido?
-- [JOIN, GROUP BY, HAVING]
SELECT c.id_cliente,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       COUNT(p.id_pedido) AS qtd_pedidos
FROM cliente c
LEFT JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = c.id_cliente
JOIN pedido p           ON p.id_cliente  = c.id_cliente
GROUP BY c.id_cliente, pf.nome, pf.sobrenome, pj.razao_social
HAVING COUNT(p.id_pedido) > 1;


-- Q7. Qual o valor total de cada pedido (itens + frete), do maior para o menor?
-- [atributo derivado (SUM + frete), JOIN, GROUP BY, ORDER BY]
SELECT p.id_pedido,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       p.status_pedido,
       SUM(i.quantidade * i.preco_unitario)            AS subtotal_itens,
       p.frete,
       SUM(i.quantidade * i.preco_unitario) + p.frete  AS total_pedido
FROM pedido p
JOIN item_pedido i      ON i.id_pedido  = p.id_pedido
LEFT JOIN cliente_pf pf ON pf.id_cliente = p.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = p.id_cliente
GROUP BY p.id_pedido, pf.nome, pf.sobrenome, pj.razao_social, p.status_pedido, p.frete
ORDER BY total_pedido DESC;


-- Q8. Quais clientes já pagaram (pagamentos aprovados) mais de R$ 200,00 no total?
-- [JOIN, WHERE, GROUP BY, HAVING, ORDER BY]
SELECT c.id_cliente,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       SUM(pp.valor) AS total_pago
FROM cliente c
LEFT JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = c.id_cliente
JOIN pedido_pagamento pp ON pp.id_cliente = c.id_cliente
WHERE pp.status_pagamento = 'APROVADO'
GROUP BY c.id_cliente, pf.nome, pf.sobrenome, pj.razao_social
HAVING SUM(pp.valor) > 200
ORDER BY total_pago DESC;


-- Q9. Quais clientes têm mais de uma forma de pagamento cadastrada?
-- [JOIN, GROUP BY, HAVING]
SELECT c.id_cliente,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       COUNT(fp.id_forma_pagamento) AS qtd_formas,
       GROUP_CONCAT(fp.tipo ORDER BY fp.tipo SEPARATOR ', ') AS formas
FROM cliente c
LEFT JOIN cliente_pf pf ON pf.id_cliente = c.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = c.id_cliente
JOIN forma_pagamento fp ON fp.id_cliente = c.id_cliente
GROUP BY c.id_cliente, pf.nome, pf.sobrenome, pj.razao_social
HAVING COUNT(fp.id_forma_pagamento) > 1;


-- Q10. Quais pedidos foram pagos com mais de uma forma de pagamento?
-- [JOIN, GROUP BY, HAVING, atributo derivado]
SELECT pp.id_pedido,
       COUNT(*)        AS qtd_pagamentos,
       SUM(pp.valor)   AS total_pago,
       GROUP_CONCAT(fp.tipo ORDER BY fp.tipo SEPARATOR ' + ') AS combinacao
FROM pedido_pagamento pp
JOIN forma_pagamento fp ON fp.id_forma_pagamento = pp.id_forma_pagamento
GROUP BY pp.id_pedido
HAVING COUNT(*) > 1;


-- Q11. Algum vendedor também é fornecedor?
-- [JOIN entre vendedor e fornecedor pelo CNPJ]
SELECT v.id_vendedor, v.razao_social AS vendedor,
       f.id_fornecedor, f.razao_social AS fornecedor,
       v.cnpj
FROM vendedor v
JOIN fornecedor f ON f.cnpj = v.cnpj;


-- Q12. Qual a relação de produtos, fornecedores e estoque (com alerta de reposição)?
-- [JOIN, LEFT JOIN, GROUP BY, atributo derivado (CASE), ORDER BY]
SELECT p.nome AS produto,
       f.razao_social AS fornecedor,
       COALESCE(SUM(pe.quantidade), 0) AS estoque_total,
       CASE
           WHEN COALESCE(SUM(pe.quantidade), 0) = 0 THEN 'SEM ESTOQUE'
           WHEN COALESCE(SUM(pe.quantidade), 0) < 10 THEN 'ESTOQUE BAIXO'
           ELSE 'OK'
       END AS situacao
FROM produto p
JOIN produto_fornecedor pfo ON pfo.id_produto    = p.id_produto
JOIN fornecedor f           ON f.id_fornecedor   = pfo.id_fornecedor
LEFT JOIN produto_estoque pe ON pe.id_produto    = p.id_produto
GROUP BY p.id_produto, p.nome, f.razao_social
ORDER BY estoque_total ASC;


-- Q13. Qual a relação de nomes dos fornecedores e nomes dos produtos que fornecem?
-- [JOIN, ORDER BY]
SELECT f.razao_social AS fornecedor, p.nome AS produto, pfo.preco_custo
FROM fornecedor f
JOIN produto_fornecedor pfo ON pfo.id_fornecedor = f.id_fornecedor
JOIN produto p              ON p.id_produto      = pfo.id_produto
ORDER BY f.razao_social, p.nome;


-- Q14. Qual a margem de lucro de cada produto (preço de venda x custo do fornecedor)?
-- [atributos derivados, JOIN, ORDER BY]
SELECT p.nome,
       p.valor                                            AS preco_venda,
       pfo.preco_custo,
       p.valor - pfo.preco_custo                          AS margem_reais,
       ROUND((p.valor - pfo.preco_custo) / p.valor * 100, 1) AS margem_percentual
FROM produto p
JOIN produto_fornecedor pfo ON pfo.id_produto = p.id_produto
ORDER BY margem_percentual DESC;


-- Q15. Quais categorias geraram mais de R$ 100,00 de receita (ignorando pedidos cancelados)?
-- [JOIN, WHERE, GROUP BY, HAVING, ORDER BY]
SELECT pr.categoria,
       SUM(i.quantidade)                     AS unidades_vendidas,
       SUM(i.quantidade * i.preco_unitario)  AS receita
FROM item_pedido i
JOIN produto pr ON pr.id_produto = i.id_produto
JOIN pedido p   ON p.id_pedido   = i.id_pedido
WHERE p.status_pedido <> 'CANCELADO'
GROUP BY pr.categoria
HAVING SUM(i.quantidade * i.preco_unitario) > 100
ORDER BY receita DESC;


-- Q16. Como estão as entregas em andamento (status e código de rastreio) e para onde vão?
-- [JOIN de várias tabelas, WHERE, atributo derivado (IF), ORDER BY]
SELECT e.id_entrega, e.id_pedido,
       COALESCE(CONCAT(pf.nome, ' ', pf.sobrenome), pj.razao_social) AS cliente,
       en.cidade AS destino,
       e.status_entrega,
       IF(e.codigo_rastreio IS NULL, 'Sem código', e.codigo_rastreio) AS rastreio,
       e.data_previsao
FROM entrega e
JOIN pedido p           ON p.id_pedido   = e.id_pedido
JOIN endereco en        ON en.id_endereco = p.id_endereco
LEFT JOIN cliente_pf pf ON pf.id_cliente = p.id_cliente
LEFT JOIN cliente_pj pj ON pj.id_cliente = p.id_cliente
WHERE e.status_entrega NOT IN ('ENTREGUE','CANCELADA')
ORDER BY e.data_previsao IS NULL, e.data_previsao;


-- Q17. Quantas entregas existem em cada status?
-- [GROUP BY, ORDER BY]
SELECT status_entrega, COUNT(*) AS qtd
FROM entrega
GROUP BY status_entrega
ORDER BY qtd DESC;


-- TESTE DE REGRA (deve FALHAR): cliente 1 é PF e não pode ter registro PJ.
-- INSERT INTO cliente_pj (id_cliente, razao_social, cnpj) VALUES (1, 'Teste', '99999999000100');
