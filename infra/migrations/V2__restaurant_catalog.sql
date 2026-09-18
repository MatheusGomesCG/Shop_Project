CREATE TABLE restaurants (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(160) NOT NULL CHECK (btrim(name) <> ''),
    slug varchar(180) NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
    description text,
    cuisine varchar(80) NOT NULL,
    image_url text,
    rating numeric(3,2) NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5),
    delivery_fee numeric(12,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    minimum_order numeric(12,2) NOT NULL DEFAULT 0 CHECK (minimum_order >= 0),
    estimated_delivery_minutes integer NOT NULL CHECK (estimated_delivery_minutes > 0),
    is_open boolean NOT NULL DEFAULT false,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX restaurants_name_trgm_idx ON restaurants USING gin(name gin_trgm_ops);

CREATE TABLE categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id uuid NOT NULL REFERENCES restaurants(id),
    name varchar(100) NOT NULL CHECK (btrim(name) <> ''),
    sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
    active boolean NOT NULL DEFAULT true,
    UNIQUE (restaurant_id, name),
    UNIQUE (id, restaurant_id)
);

CREATE TABLE products (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    restaurant_id uuid NOT NULL REFERENCES restaurants(id),
    category_id uuid NOT NULL,
    name varchar(160) NOT NULL CHECK (btrim(name) <> ''),
    description text,
    image_url text,
    price numeric(12,2) NOT NULL CHECK (price >= 0),
    status varchar(16) NOT NULL DEFAULT 'RASCUNHO'
        CHECK (status IN ('ATIVO', 'ESGOTADO', 'RASCUNHO')),
    deleted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, restaurant_id),
    FOREIGN KEY (category_id, restaurant_id) REFERENCES categories(id, restaurant_id)
);

CREATE INDEX products_name_trgm_idx ON products USING gin(name gin_trgm_ops);
CREATE INDEX products_menu_idx ON products(restaurant_id, category_id, status) WHERE deleted_at IS NULL;

CREATE TABLE product_option_groups (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id uuid NOT NULL REFERENCES products(id),
    name varchar(100) NOT NULL CHECK (btrim(name) <> ''),
    min_select integer NOT NULL DEFAULT 0 CHECK (min_select >= 0),
    max_select integer NOT NULL DEFAULT 1 CHECK (max_select >= min_select),
    sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
    UNIQUE (product_id, name),
    UNIQUE (id, product_id)
);

CREATE TABLE product_options (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id uuid NOT NULL,
    product_id uuid NOT NULL,
    name varchar(100) NOT NULL CHECK (btrim(name) <> ''),
    price_delta numeric(12,2) NOT NULL DEFAULT 0 CHECK (price_delta >= 0),
    available boolean NOT NULL DEFAULT true,
    sort_order integer NOT NULL DEFAULT 0 CHECK (sort_order >= 0),
    UNIQUE (group_id, name),
    UNIQUE (id, product_id),
    FOREIGN KEY (group_id, product_id) REFERENCES product_option_groups(id, product_id)
);
