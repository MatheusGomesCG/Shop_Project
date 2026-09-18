CREATE TABLE carts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL UNIQUE REFERENCES users(id),
    restaurant_id uuid NOT NULL REFERENCES restaurants(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, restaurant_id)
);

CREATE TABLE cart_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cart_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 999),
    notes varchar(500),
    created_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, product_id),
    FOREIGN KEY (cart_id, restaurant_id) REFERENCES carts(id, restaurant_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id, restaurant_id) REFERENCES products(id, restaurant_id)
);

CREATE INDEX cart_items_cart_idx ON cart_items(cart_id);

CREATE TABLE cart_item_options (
    cart_item_id uuid NOT NULL,
    option_id uuid NOT NULL,
    product_id uuid NOT NULL,
    quantity integer NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 999),
    PRIMARY KEY (cart_item_id, option_id),
    FOREIGN KEY (cart_item_id, product_id) REFERENCES cart_items(id, product_id) ON DELETE CASCADE,
    FOREIGN KEY (option_id, product_id) REFERENCES product_options(id, product_id)
);

CREATE TABLE orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(24) NOT NULL UNIQUE,
    idempotency_key uuid NOT NULL UNIQUE,
    user_id uuid NOT NULL REFERENCES users(id),
    restaurant_id uuid NOT NULL REFERENCES restaurants(id),
    address_id uuid NOT NULL,
    status varchar(20) NOT NULL DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE', 'CONFIRMADO', 'EM_PREPARO', 'EM_ENTREGA', 'ENTREGUE', 'CANCELADO')),
    subtotal numeric(12,2) NOT NULL CHECK (subtotal >= 0),
    delivery_fee numeric(12,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    discount numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
    total numeric(12,2) NOT NULL CHECK (total >= 0),
    delivery_recipient_name varchar(160) NOT NULL,
    delivery_street varchar(200) NOT NULL,
    delivery_number varchar(20) NOT NULL,
    delivery_complement varchar(120),
    delivery_neighborhood varchar(120) NOT NULL,
    delivery_city varchar(120) NOT NULL,
    delivery_state char(2) NOT NULL CHECK (delivery_state ~ '^[A-Z]{2}$'),
    delivery_postal_code varchar(8) NOT NULL CHECK (delivery_postal_code ~ '^[0-9]{8}$'),
    notes varchar(500),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, user_id),
    UNIQUE (id, restaurant_id),
    FOREIGN KEY (address_id, user_id) REFERENCES addresses(id, user_id),
    CHECK (discount <= subtotal + delivery_fee),
    CHECK (total = subtotal + delivery_fee - discount)
);

CREATE INDEX orders_status_created_idx ON orders(status, created_at DESC);
CREATE INDEX orders_user_created_idx ON orders(user_id, created_at DESC);
CREATE INDEX orders_restaurant_created_idx ON orders(restaurant_id, created_at DESC);

CREATE TABLE order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    restaurant_id uuid NOT NULL,
    product_id uuid NOT NULL,
    product_name varchar(160) NOT NULL,
    unit_price numeric(12,2) NOT NULL CHECK (unit_price >= 0),
    options_price numeric(12,2) NOT NULL DEFAULT 0 CHECK (options_price >= 0),
    quantity integer NOT NULL CHECK (quantity BETWEEN 1 AND 999),
    total numeric(12,2) NOT NULL CHECK (total >= 0),
    notes varchar(500),
    UNIQUE (id, product_id),
    FOREIGN KEY (order_id, restaurant_id) REFERENCES orders(id, restaurant_id),
    FOREIGN KEY (product_id, restaurant_id) REFERENCES products(id, restaurant_id),
    CHECK (total = (unit_price + options_price) * quantity)
);

CREATE INDEX order_items_order_idx ON order_items(order_id);

CREATE TABLE order_item_options (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_item_id uuid NOT NULL,
    option_id uuid NOT NULL,
    product_id uuid NOT NULL,
    option_name varchar(100) NOT NULL,
    price_delta numeric(12,2) NOT NULL CHECK (price_delta >= 0),
    quantity integer NOT NULL DEFAULT 1 CHECK (quantity BETWEEN 1 AND 999),
    UNIQUE (order_item_id, option_id),
    FOREIGN KEY (order_item_id, product_id) REFERENCES order_items(id, product_id),
    FOREIGN KEY (option_id, product_id) REFERENCES product_options(id, product_id)
);

CREATE TABLE order_status_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id),
    previous_status varchar(20)
        CHECK (previous_status IN ('PENDENTE', 'CONFIRMADO', 'EM_PREPARO', 'EM_ENTREGA', 'ENTREGUE', 'CANCELADO')),
    status varchar(20) NOT NULL
        CHECK (status IN ('PENDENTE', 'CONFIRMADO', 'EM_PREPARO', 'EM_ENTREGA', 'ENTREGUE', 'CANCELADO')),
    author_id uuid NOT NULL REFERENCES users(id),
    author_role varchar(16) NOT NULL CHECK (author_role IN ('CUSTOMER', 'ADMIN', 'OPERACAO')),
    reason varchar(500) NOT NULL CHECK (btrim(reason) <> ''),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (previous_status IS NULL OR previous_status <> status)
);

CREATE INDEX order_status_history_order_idx ON order_status_history(order_id, created_at);
