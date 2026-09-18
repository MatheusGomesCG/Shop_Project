CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

CREATE TABLE users (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(160) NOT NULL CHECK (btrim(name) <> ''),
    email varchar(254) NOT NULL UNIQUE,
    cpf varchar(11) NOT NULL UNIQUE CHECK (cpf ~ '^[0-9]{11}$'),
    password_hash varchar(255) NOT NULL,
    phone varchar(20),
    role varchar(16) NOT NULL DEFAULT 'CUSTOMER'
        CHECK (role IN ('CUSTOMER', 'ADMIN', 'OPERACAO')),
    wallet_balance numeric(12,2) NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
    enabled boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT users_email_normalized CHECK (email = lower(btrim(email)))
);

CREATE TABLE addresses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    label varchar(60) NOT NULL,
    recipient_name varchar(160) NOT NULL,
    street varchar(200) NOT NULL,
    number varchar(20) NOT NULL,
    complement varchar(120),
    neighborhood varchar(120) NOT NULL,
    city varchar(120) NOT NULL,
    state char(2) NOT NULL CHECK (state ~ '^[A-Z]{2}$'),
    postal_code varchar(8) NOT NULL CHECK (postal_code ~ '^[0-9]{8}$'),
    latitude numeric(9,6) CHECK (latitude BETWEEN -90 AND 90),
    longitude numeric(9,6) CHECK (longitude BETWEEN -180 AND 180),
    is_default boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, user_id),
    CHECK ((latitude IS NULL) = (longitude IS NULL))
);

CREATE UNIQUE INDEX addresses_one_default_per_user ON addresses(user_id) WHERE is_default;
CREATE INDEX addresses_user_idx ON addresses(user_id);

CREATE TABLE refresh_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    token_hash varchar(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    family_id uuid NOT NULL DEFAULT gen_random_uuid(),
    expires_at timestamptz NOT NULL,
    revoked_at timestamptz,
    replaced_by uuid REFERENCES refresh_tokens(id),
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (expires_at > created_at),
    CHECK (revoked_at IS NULL OR revoked_at >= created_at),
    CHECK (replaced_by IS NULL OR replaced_by <> id)
);

CREATE INDEX refresh_tokens_user_idx ON refresh_tokens(user_id);
CREATE INDEX refresh_tokens_family_idx ON refresh_tokens(family_id);
CREATE INDEX refresh_tokens_expiry_idx ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;
