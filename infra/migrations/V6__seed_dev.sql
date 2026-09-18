INSERT INTO restaurants(id, name, slug, description, cuisine, rating, delivery_fee, minimum_order, estimated_delivery_minutes, is_open)
VALUES
    ('10000000-0000-4000-8000-000000000001', 'Casa Aurora', 'casa-aurora', 'Cozinha brasileira de estação.', 'Brasileira', 4.90, 7.90, 25.00, 35, true),
    ('10000000-0000-4000-8000-000000000002', 'Mérito Grill', 'merito-grill', 'Cortes na brasa e acompanhamentos.', 'Grelhados', 4.80, 9.90, 35.00, 45, true),
    ('10000000-0000-4000-8000-000000000003', 'Kaisen Omakase', 'kaisen-omakase', 'Cozinha japonesa com ingredientes selecionados.', 'Japonesa', 4.90, 11.90, 50.00, 50, true),
    ('10000000-0000-4000-8000-000000000004', 'Trattoria Nove', 'trattoria-nove', 'Massas e clássicos italianos.', 'Italiana', 4.70, 8.90, 30.00, 40, true),
    ('10000000-0000-4000-8000-000000000005', 'Verde Fundo', 'verde-fundo', 'Pratos vegetais e sazonais.', 'Vegetariana', 4.80, 6.90, 25.00, 30, true),
    ('10000000-0000-4000-8000-000000000006', 'Doce Ofício', 'doce-oficio', 'Doces e sobremesas artesanais.', 'Confeitaria', 4.90, 5.90, 15.00, 25, true);

INSERT INTO categories(id, restaurant_id, name, sort_order)
VALUES
    ('20000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Entradas', 1),
    ('20000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Pratos principais', 2),
    ('20000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'Sobremesas', 3),
    ('20000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'Bebidas', 4);

INSERT INTO products(id, restaurant_id, category_id, name, description, price, status)
VALUES
    ('30000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Dadinho de tapioca', 'Com geleia de pimenta da casa.', 24.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000001', 'Salada da estação', 'Folhas, legumes e molho de limão.', 21.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002', 'Baião de dois', 'Arroz, feijão e queijo coalho.', 42.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000002', 'Peixe com purê de mandioquinha', 'Peixe grelhado, purê e ervas.', 54.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000003', 'Pudim da casa', 'Pudim com calda de caramelo.', 16.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000003', 'Brownie de chocolate', 'Com chocolate brasileiro.', 19.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000004', 'Suco de maracujá', 'Suco natural, 300 ml.', 9.90, 'ATIVO'),
    ('30000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000001', '20000000-0000-4000-8000-000000000004', 'Água mineral', 'Sem gás, 500 ml.', 5.90, 'ATIVO');

INSERT INTO product_option_groups(id, product_id, name, min_select, max_select, sort_order)
VALUES
    ('40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'Adicionais', 0, 2, 1),
    ('40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000007', 'Açúcar', 1, 1, 1);

INSERT INTO product_options(id, group_id, product_id, name, price_delta, sort_order)
VALUES
    ('50000000-0000-4000-8000-000000000001', '40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'Queijo coalho', 6.00, 1),
    ('50000000-0000-4000-8000-000000000002', '40000000-0000-4000-8000-000000000001', '30000000-0000-4000-8000-000000000003', 'Carne de sol', 12.00, 2),
    ('50000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000007', 'Sem açúcar', 0.00, 1),
    ('50000000-0000-4000-8000-000000000004', '40000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000007', 'Com açúcar', 0.00, 2);

INSERT INTO coupons(id, code, type, discount_value, maximum_discount, minimum_order, valid_from, valid_until, total_limit, per_user_limit)
VALUES
    ('60000000-0000-4000-8000-000000000001', 'AURORA10', 'PERCENT', 10.00, 20.00, 30.00, '2020-01-01T00:00:00Z', '2099-12-31T23:59:59Z', 1000, 1),
    ('60000000-0000-4000-8000-000000000002', 'FRETEGRATIS', 'FREE_SHIPPING', 0.00, 15.00, 50.00, '2020-01-01T00:00:00Z', '2099-12-31T23:59:59Z', 500, 2);

INSERT INTO couriers(id, name, cpf, phone, vehicle, status, latitude, longitude)
VALUES
    ('70000000-0000-4000-8000-000000000001', 'Entregador Demo 1', '00000000001', '+5500000000001', 'BIKE', 'DISPONIVEL', -23.550520, -46.633308),
    ('70000000-0000-4000-8000-000000000002', 'Entregador Demo 2', '00000000002', '+5500000000002', 'MOTO', 'DISPONIVEL', -23.555000, -46.640000);
