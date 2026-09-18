CREATE TABLE coupons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    code varchar(40) NOT NULL UNIQUE,
    type varchar(16) NOT NULL CHECK (type IN ('PERCENT', 'AMOUNT', 'FREE_SHIPPING')),
    discount_value numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount_value >= 0),
    maximum_discount numeric(12,2) CHECK (maximum_discount >= 0),
    minimum_order numeric(12,2) NOT NULL DEFAULT 0 CHECK (minimum_order >= 0),
    valid_from timestamptz NOT NULL,
    valid_until timestamptz NOT NULL,
    total_limit integer CHECK (total_limit > 0),
    per_user_limit integer NOT NULL DEFAULT 1 CHECK (per_user_limit > 0),
    redemption_count integer NOT NULL DEFAULT 0 CHECK (redemption_count >= 0),
    active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CHECK (code = upper(btrim(code)) AND code ~ '^[A-Z0-9_-]+$'),
    CHECK (valid_until > valid_from),
    CHECK (total_limit IS NULL OR redemption_count <= total_limit),
    CHECK (
        (type = 'PERCENT' AND discount_value > 0 AND discount_value <= 100)
        OR (type = 'AMOUNT' AND discount_value > 0)
        OR (type = 'FREE_SHIPPING' AND discount_value = 0)
    )
);

CREATE TABLE coupon_user_usage (
    coupon_id uuid NOT NULL REFERENCES coupons(id),
    user_id uuid NOT NULL REFERENCES users(id),
    redemption_count integer NOT NULL CHECK (redemption_count > 0),
    PRIMARY KEY (coupon_id, user_id)
);

CREATE TABLE coupon_redemptions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL,
    coupon_id uuid NOT NULL REFERENCES coupons(id),
    user_id uuid NOT NULL REFERENCES users(id),
    discount_amount numeric(12,2) NOT NULL CHECK (discount_amount >= 0),
    redeemed_at timestamptz NOT NULL DEFAULT now(),
    UNIQUE (order_id, coupon_id),
    FOREIGN KEY (order_id, user_id) REFERENCES orders(id, user_id)
);

CREATE INDEX coupon_redemptions_user_idx ON coupon_redemptions(coupon_id, user_id);

-- UPDATE serializa o consumo do mesmo cupom; AFTER INSERT não cobra duplicatas ignoradas.
CREATE FUNCTION enforce_coupon_redemption() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    coupon_row coupons%ROWTYPE;
    order_row orders%ROWTYPE;
    user_count integer;
    allowed_discount numeric(12,2);
BEGIN
    UPDATE coupons
       SET redemption_count = redemption_count + 1
     WHERE id = NEW.coupon_id
       AND active
       AND CURRENT_TIMESTAMP >= valid_from
       AND CURRENT_TIMESTAMP < valid_until
       AND (total_limit IS NULL OR redemption_count < total_limit)
    RETURNING * INTO coupon_row;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cupom inativo, fora da validade ou com limite total atingido'
            USING ERRCODE = '23514';
    END IF;

    INSERT INTO coupon_user_usage(coupon_id, user_id, redemption_count)
    VALUES (NEW.coupon_id, NEW.user_id, 1)
    ON CONFLICT (coupon_id, user_id) DO UPDATE
        SET redemption_count = coupon_user_usage.redemption_count + 1
    RETURNING redemption_count INTO user_count;

    IF user_count > coupon_row.per_user_limit THEN
        RAISE EXCEPTION 'Limite do cupom por usuário atingido' USING ERRCODE = '23514';
    END IF;

    SELECT * INTO STRICT order_row FROM orders WHERE id = NEW.order_id FOR SHARE;
    IF order_row.subtotal < coupon_row.minimum_order THEN
        RAISE EXCEPTION 'Pedido abaixo do valor mínimo do cupom' USING ERRCODE = '23514';
    END IF;

    allowed_discount := CASE coupon_row.type
        WHEN 'PERCENT' THEN round(order_row.subtotal * coupon_row.discount_value / 100, 2)
        WHEN 'AMOUNT' THEN coupon_row.discount_value
        WHEN 'FREE_SHIPPING' THEN order_row.delivery_fee
    END;
    allowed_discount := least(allowed_discount, order_row.subtotal + order_row.delivery_fee);
    IF coupon_row.maximum_discount IS NOT NULL THEN
        allowed_discount := least(allowed_discount, coupon_row.maximum_discount);
    END IF;
    IF NEW.discount_amount > allowed_discount THEN
        RAISE EXCEPTION 'Desconto excede o valor permitido pelo cupom' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER coupon_redemptions_enforce_limits
AFTER INSERT ON coupon_redemptions FOR EACH ROW EXECUTE FUNCTION enforce_coupon_redemption();

CREATE FUNCTION prevent_coupon_redemption_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'Resgate de cupom é imutável; cancelamento não devolve utilização'
        USING ERRCODE = '23514';
END;
$$;

CREATE TRIGGER coupon_redemptions_immutable
BEFORE UPDATE OR DELETE ON coupon_redemptions FOR EACH ROW EXECUTE FUNCTION prevent_coupon_redemption_change();

CREATE FUNCTION enforce_coupon_user_limit_change() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.per_user_limit < OLD.per_user_limit AND EXISTS (
        SELECT 1 FROM coupon_user_usage
        WHERE coupon_id = NEW.id AND redemption_count > NEW.per_user_limit
    ) THEN
        RAISE EXCEPTION 'Novo limite por usuário é inferior aos resgates existentes'
            USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER coupons_validate_user_limit
BEFORE UPDATE OF per_user_limit ON coupons FOR EACH ROW EXECUTE FUNCTION enforce_coupon_user_limit_change();

CREATE TABLE payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id),
    idempotency_key uuid NOT NULL UNIQUE,
    method varchar(20) NOT NULL
        CHECK (method IN ('PIX', 'CARTAO_CREDITO', 'CARTAO_DEBITO', 'DINHEIRO', 'CARTEIRA', 'VALE_REFEICAO')),
    status varchar(16) NOT NULL DEFAULT 'PENDENTE'
        CHECK (status IN ('PENDENTE', 'APROVADO', 'RECUSADO', 'ESTORNADO', 'CANCELADO')),
    amount numeric(12,2) NOT NULL CHECK (amount >= 0),
    change_for numeric(12,2) CHECK (change_for >= amount),
    pix_txid varchar(35),
    pix_expires_at timestamptz,
    provider_reference varchar(160),
    refusal_reason varchar(32)
        CHECK (refusal_reason IN ('INSUFFICIENT_FUNDS', 'INVALID_PAYMENT_DATA', 'EXPIRED', 'FRAUD_SUSPECTED', 'PROVIDER_UNAVAILABLE')),
    approved_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CHECK (pix_txid IS NULL OR (method = 'PIX' AND btrim(pix_txid) <> '')),
    CHECK (change_for IS NULL OR method = 'DINHEIRO'),
    CHECK ((status = 'RECUSADO') = (refusal_reason IS NOT NULL))
);

CREATE UNIQUE INDEX payments_pix_txid_unique ON payments(pix_txid) WHERE pix_txid IS NOT NULL;
CREATE INDEX payments_order_idx ON payments(order_id, created_at DESC);

CREATE TABLE wallet_entries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES users(id),
    order_id uuid,
    payment_id uuid REFERENCES payments(id),
    idempotency_key uuid NOT NULL UNIQUE,
    type varchar(16) NOT NULL CHECK (type IN ('CREDIT', 'DEBIT', 'REFUND')),
    amount numeric(12,2) NOT NULL CHECK (amount > 0),
    balance_after numeric(12,2) NOT NULL CHECK (balance_after >= 0),
    description varchar(255) NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (order_id, user_id) REFERENCES orders(id, user_id)
);

CREATE INDEX wallet_entries_user_created_idx ON wallet_entries(user_id, created_at DESC);
