CREATE TABLE couriers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(160) NOT NULL CHECK (btrim(name) <> ''),
    cpf varchar(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    phone varchar(20) NOT NULL,
    vehicle varchar(10) NOT NULL CHECK (vehicle IN ('BIKE', 'MOTO', 'CARRO')),
    license_plate varchar(7),
    status varchar(16) NOT NULL DEFAULT 'OFFLINE' CHECK (status IN ('OFFLINE', 'DISPONIVEL', 'EM_ENTREGA')),
    latitude numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
    position_updated_at timestamptz,
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CHECK (license_plate IS NULL OR license_plate ~ '^[A-Z0-9]{7}$')
);

CREATE TABLE deliveries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL UNIQUE REFERENCES orders(id),
    courier_id uuid NOT NULL REFERENCES couriers(id),
    status varchar(16) NOT NULL DEFAULT 'ATRIBUIDA'
        CHECK (status IN ('ATRIBUIDA', 'EM_COLETA', 'EM_ROTA', 'ENTREGUE', 'CANCELADA')),
    assigned_at timestamptz NOT NULL DEFAULT now(),
    picked_up_at timestamptz,
    delivered_at timestamptz,
    estimated_arrival_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (estimated_arrival_at >= assigned_at),
    CHECK (picked_up_at IS NULL OR picked_up_at >= assigned_at),
    CHECK (delivered_at IS NULL OR (picked_up_at IS NOT NULL AND delivered_at >= picked_up_at))
);

CREATE INDEX deliveries_courier_status_idx ON deliveries(courier_id, status);

CREATE TABLE delivery_events (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id uuid NOT NULL REFERENCES deliveries(id),
    event_id uuid NOT NULL UNIQUE,
    type varchar(16) NOT NULL CHECK (type IN ('ATRIBUIDA', 'COLETADA', 'POSICAO', 'ENTREGUE', 'CANCELADA')),
    latitude numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
    note varchar(500),
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    CHECK ((latitude IS NULL) = (longitude IS NULL)),
    CHECK (type <> 'POSICAO' OR latitude IS NOT NULL)
);

CREATE INDEX delivery_events_delivery_time_idx ON delivery_events(delivery_id, occurred_at);
