import { randomInt, randomUUID } from 'node:crypto';
import { expect, test, type APIRequestContext, type Page, type Request } from '@playwright/test';

function createCpf(): string {
  const digits = Array.from({ length: 9 }, () => randomInt(0, 10));
  if (digits.every((digit) => digit === digits[0])) digits[0] = (digits[0] + 1) % 10;
  for (const length of [9, 10]) {
    const sum = digits.reduce((value, digit, index) => value + digit * (length + 1 - index), 0);
    const remainder = (sum * 10) % 11;
    digits.push(remainder === 10 ? 0 : remainder);
  }
  return digits.join('');
}

async function prepareCustomer(request: APIRequestContext) {
  const customer = {
    name: 'Cliente E2E',
    email: `e2e-${randomUUID()}@example.test`,
    cpf: createCpf(),
    password: `E2e!${randomUUID()}`,
  };
  const registered = await request.post('/api/auth/register', { data: customer });
  expect(registered.status(), 'Cadastro isolado deve criar um cliente').toBe(201);
  const login = await request.post('/api/auth/login', {
    data: { email: customer.email, password: customer.password },
  });
  expect(login.status()).toBe(200);
  const { accessToken } = await login.json();
  expect(accessToken).toEqual(expect.any(String));
  const headers = { Authorization: `Bearer ${accessToken}` };
  const address = await request.post('/api/addresses', {
    headers,
    data: {
      label: 'Casa', postalCode: '01310100', street: 'Avenida Paulista', number: '1000',
      neighborhood: 'Bela Vista', city: 'São Paulo', state: 'SP', isDefault: true,
    },
  });
  expect(address.status()).toBe(201);
  return { ...customer, headers };
}

async function checkout(page: Page, customer: { email: string; password: string }) {
  await page.goto('/login');
  await page.getByTestId('login-email').fill(customer.email);
  await page.getByTestId('login-password').fill(customer.password);
  await page.getByTestId('login-submit').click();
  await page.getByTestId('restaurant-card').filter({ hasText: 'Casa Aurora' }).click();
  await page.getByTestId('menu-item-add').first().click();
  await expect(page.getByTestId('cart-badge')).toHaveText('1');
  await page.getByTestId('go-to-cart').click();
  await expect(page.getByTestId('cart-total')).toContainText('R$');
  await page.getByTestId('go-to-checkout').click();
  await page.getByTestId('payment-pix').click();
}

test('login, compra com Pix e rastreio do pedido', async ({ page, request }) => {
  const customer = await prepareCustomer(request);
  await checkout(page, customer);
  const created = page.waitForResponse((response) =>
    new URL(response.url()).pathname === '/api/orders' && response.request().method() === 'POST');
  await page.getByTestId('place-order').click();
  expect((await created).status()).toBe(201);
  await expect(page.getByTestId('pix-qr')).toBeVisible();
  await expect(page.getByTestId('order-confirmed')).toBeVisible();
  await expect(page.getByTestId('order-code')).not.toBeEmpty();
  await page.getByTestId('track-order').click();
  await expect(page.getByTestId('tracking-timeline')).toBeVisible();
  await expect(page.getByTestId('tracking-status')).toHaveText(/EM_ENTREGA|ENTREGUE/);
});

test('duplo clique em confirmar persiste somente um pedido', async ({ page, request }) => {
  const customer = await prepareCustomer(request);
  await checkout(page, customer);
  const requests: Request[] = [];
  let release!: () => void;
  const pending = new Promise<void>((resolve) => { release = resolve; });

  // Mantém a resposta pendente durante os dois cliques, sem simular o backend.
  await page.route('**/api/orders', async (route) => {
    if (route.request().method() === 'POST') {
      requests.push(route.request());
      await pending;
    }
    await route.continue();
  });
  try {
    await page.getByTestId('place-order').dblclick();
  } finally {
    release();
  }
  await expect(page.getByTestId('order-confirmed')).toBeVisible();
  expect(requests.length).toBeGreaterThan(0);
  for (const sent of requests) {
    const response = await sent.response();
    expect(response, 'Pedido deve obter resposta do backend').not.toBeNull();
    await response!.finished();
    expect([200, 201]).toContain(response!.status());
  }

  const initial = requests[0];
  const idempotencyKey = initial.headers()['idempotency-key'];
  expect(idempotencyKey, 'Checkout precisa reutilizar Idempotency-Key').toBeTruthy();
  // Reenvio concorrente verifica também a proteção persistida, além do botão desabilitado.
  const repeated = await Promise.all([0, 1].map(() => request.post('/api/orders', {
    headers: { ...customer.headers, 'Idempotency-Key': idempotencyKey },
    data: initial.postDataJSON(),
  })));
  for (const response of repeated) expect([200, 201]).toContain(response.status());
  const orders = await request.get('/api/orders', { headers: customer.headers });
  expect(orders.status()).toBe(200);
  const { content, totalElements } = await orders.json();
  expect(totalElements, 'Reenvios não podem duplicar pedidos no banco').toBe(1);
  expect(content).toHaveLength(1);
  await expect(page.getByTestId('order-code')).toHaveText(content[0].code);
});
