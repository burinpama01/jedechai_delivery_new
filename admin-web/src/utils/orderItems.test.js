import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildOrderItemsPayload,
  getOrderItemsPriceChange,
  renderAdminNote,
  renderCancellationReason,
  renderOrderItemRows,
  renderSelectedOptions,
  validateOrderItemsPayload,
} from './orderItems.js';

const escapeHtml = (value) => String(value)
  .replace(/&/g, '&amp;')
  .replace(/</g, '&lt;')
  .replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;')
  .replace(/'/g, '&#39;');

test('renderSelectedOptions renders grouped JSON choices', () => {
  const html = renderSelectedOptions(JSON.stringify([
    { group: 'Size', value: 'Large' },
    { group_name: 'Toppings', choices: [{ name: 'Egg' }, { name: 'Cheese' }] },
  ]), escapeHtml);

  assert.match(html, /Size: Large/);
  assert.match(html, /Toppings: Egg, Cheese/);
});

test('renderOrderItemRows renders selected options and note', () => {
  const html = renderOrderItemRows([
    {
      menu_name: 'Noodle',
      quantity: 2,
      price: 50,
      selected_options: [{ name: 'Spicy', value: 'Medium' }],
      note: 'no peanuts',
    },
  ], (value) => String(value), escapeHtml);

  assert.match(html, /Noodle x2/);
  assert.match(html, /Spicy: Medium/);
  assert.match(html, /Note: no peanuts/);
  assert.match(html, /฿100/);
});

test('renderAdminNote renders existing note safely', () => {
  const html = renderAdminNote('<call merchant>');

  assert.match(html, /Admin note/);
  assert.match(html, /&lt;call merchant&gt;/);
});

test('renderCancellationReason renders cancelled order reason safely', () => {
  const html = renderCancellationReason({
    status: 'cancelled',
    cancellation_reason: 'admin_force_cancel: <driver unavailable>',
  }, escapeHtml);

  assert.match(html, /เหตุผลการยกเลิก/);
  assert.match(html, /&lt;driver unavailable&gt;/);
  assert.doesNotMatch(html, /admin_force_cancel:/);
});

test('renderCancellationReason falls back to legacy cancel_reason field', () => {
  const html = renderCancellationReason({
    status: 'cancelled',
    cancel_reason: 'customer requested',
  }, escapeHtml);

  assert.match(html, /customer requested/);
});

test('getOrderItemsPriceChange calculates increase and cash guidance', () => {
  const change = getOrderItemsPriceChange({
    originalTotal: 120,
    items: [
      { price: 80, quantity: 1 },
      { price: 30, quantity: 2 },
    ],
    paymentMethod: 'cash',
  });

  assert.equal(change.newTotal, 140);
  assert.equal(change.diff, 20);
  assert.equal(change.kind, 'increase');
  assert.match(change.message, /Collect extra/);
});

test('buildOrderItemsPayload keeps only editable fields', () => {
  const payload = buildOrderItemsPayload([
    {
      id: 'booking-item-1',
      menu_item_id: 'menu-1',
      name: 'Rice',
      quantity: '2',
      price: '45',
      selected_options: [{ name: 'Size', value: 'Large' }],
      note: 'less spicy',
      created_at: 'ignore-me',
    },
  ]);

  assert.deepEqual(payload, [
    {
      menu_item_id: 'menu-1',
      name: 'Rice',
      quantity: 2,
      price: 45,
      selected_options: [{ name: 'Size', value: 'Large' }],
      note: 'less spicy',
    },
  ]);
});

test('validateOrderItemsPayload rejects empty edit lists', () => {
  assert.deepEqual(validateOrderItemsPayload([]), {
    ok: false,
    error: 'order_items_required',
  });
});

test('validateOrderItemsPayload rejects rows without menu item ids', () => {
  assert.deepEqual(validateOrderItemsPayload([
    { name: 'Rice', quantity: 1, price: 40 },
  ]), {
    ok: false,
    error: 'menu_item_id_required',
  });
});

test('validateOrderItemsPayload accepts valid editable rows', () => {
  assert.deepEqual(validateOrderItemsPayload([
    { menu_item_id: 'menu-1', name: 'Rice', quantity: 2, price: 40 },
  ]), {
    ok: true,
    error: '',
  });
});
