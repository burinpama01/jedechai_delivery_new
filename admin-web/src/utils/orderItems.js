function fallbackEscapeHtml(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function esc(value, escapeHtml) {
  const fn = escapeHtml || globalThis.escapeHtml || fallbackEscapeHtml;
  return fn(String(value ?? ''));
}

function parseOptions(value) {
  if (!value) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'object') return [value];
  if (typeof value !== 'string') return [];

  const trimmed = value.trim();
  if (!trimmed) return [];

  try {
    const parsed = JSON.parse(trimmed);
    if (Array.isArray(parsed)) return parsed;
    if (parsed && typeof parsed === 'object') return [parsed];
  } catch (_) {
    return [trimmed];
  }

  return [];
}

function optionText(option) {
  if (!option) return '';
  if (typeof option === 'string') return option;

  const group = option.group || option.group_name || option.category || option.name || option.label || '';
  const rawChoices = option.options || option.choices || option.items || option.values || option.selected || option.value || option.option || '';
  const choices = Array.isArray(rawChoices)
    ? rawChoices.map((choice) => {
      if (choice && typeof choice === 'object') return choice.name || choice.label || choice.value || '';
      return choice;
    }).filter(Boolean).join(', ')
    : rawChoices;

  if (group && choices && group !== choices) return `${group}: ${choices}`;
  return String(choices || group || '');
}

export function renderSelectedOptions(selectedOptions, escapeHtml) {
  const options = parseOptions(selectedOptions)
    .map(optionText)
    .map((text) => text.trim())
    .filter(Boolean);

  if (!options.length) return '';

  return `
    <div class="mt-1 space-y-0.5">
      ${options.map((text) => `<div class="text-[11px] leading-4 text-gray-500">+ ${esc(text, escapeHtml)}</div>`).join('')}
    </div>`;
}

export function renderOrderItemRows(items, fmt, escapeHtml) {
  if (!items || !items.length) {
    return '<div class="text-xs text-gray-400 py-1">No items</div>';
  }

  const format = fmt || ((value) => value);

  return items.map((item) => {
    const qty = Number(item.quantity || 1);
    const unitPrice = Number(item.price || item.unit_price || 0);
    const total = Math.round(unitPrice * (Number.isFinite(qty) ? qty : 1));
    const name = item.name || item.menu_name || item.item_name || '-';
    const optionsHtml = renderSelectedOptions(item.selected_options || item.options || item.option_details, escapeHtml);
    const note = item.note || item.special_instructions || '';

    return `
      <div class="py-2 border-b border-gray-100 last:border-b-0">
        <div class="flex justify-between gap-3 text-xs">
          <div class="min-w-0">
            <div class="font-medium text-gray-700">${esc(name, escapeHtml)} x${Number.isFinite(qty) ? qty : 1}</div>
            ${optionsHtml}
            ${note ? `<div class="mt-1 text-[11px] leading-4 text-amber-600">Note: ${esc(note, escapeHtml)}</div>` : ''}
          </div>
          <span class="shrink-0 text-gray-500">฿${format(total)}</span>
        </div>
      </div>`;
  }).join('');
}

export function renderContactCard(icon, label, person, toneClass, escapeHtml) {
  const name = person?.name || person?.full_name || person || '-';
  const phone = person?.phone || person?.phone_number || '';

  return `
    <div class="p-3 rounded-xl bg-gray-50">
      <p class="text-gray-400 mb-1">${esc(icon, escapeHtml)} ${esc(label, escapeHtml)}</p>
      <p class="font-semibold ${toneClass || ''}">${esc(name, escapeHtml)}</p>
      ${phone ? `<p class="text-gray-400">Tel ${esc(phone, escapeHtml)}</p>` : ''}
    </div>`;
}

export function renderAdminNote(note, escapeHtml) {
  const text = String(note || '').trim();
  if (!text) {
    return '<div class="text-xs text-gray-400">Admin note: -</div>';
  }

  return `
    <div class="p-3 rounded-xl bg-amber-50 border border-amber-100 text-xs">
      <p class="font-semibold text-amber-700 mb-1">Admin note</p>
      <p class="text-amber-800 whitespace-pre-wrap">${esc(text, escapeHtml)}</p>
    </div>`;
}

function normalizeCancellationReason(order) {
  const rawReason = order?.cancellation_reason
    ?? order?.cancel_reason
    ?? order?.cancellationReason
    ?? order?.cancelReason
    ?? '';

  return String(rawReason)
    .trim()
    .replace(/^admin_force_cancel:\s*/i, '')
    .trim();
}

export function renderCancellationReason(order, escapeHtml) {
  const status = String(order?.status || '').toLowerCase();
  const text = normalizeCancellationReason(order);

  if (status !== 'cancelled' && !text) return '';

  return `
    <div class="p-3 rounded-xl bg-red-50 border border-red-100 text-xs">
      <p class="font-semibold text-red-700 mb-1">เหตุผลการยกเลิก</p>
      <p class="text-red-800 whitespace-pre-wrap">${esc(text || '-', escapeHtml)}</p>
    </div>`;
}

export function getOrderItemsPriceChange({ originalTotal, items, paymentMethod } = {}) {
  const newTotal = Math.round((items || []).reduce((sum, item) => {
    const qty = Number(item.quantity || 1);
    const price = Number(item.price || 0);
    return sum + (Number.isFinite(qty) ? qty : 1) * (Number.isFinite(price) ? price : 0);
  }, 0));
  const original = Math.round(Number(originalTotal || 0));
  const diff = newTotal - original;
  const method = String(paymentMethod || '').toLowerCase();

  if (diff > 0) {
    return {
      newTotal,
      diff,
      kind: 'increase',
      toneClass: 'text-red-700 bg-red-50 border-red-100',
      message: method === 'wallet'
        ? `Collect extra ฿${diff} from wallet if balance is enough`
        : `Collect extra ฿${diff} from customer`,
    };
  }
  if (diff < 0) {
    const amount = Math.abs(diff);
    return {
      newTotal,
      diff,
      kind: 'decrease',
      toneClass: 'text-emerald-700 bg-emerald-50 border-emerald-100',
      message: method === 'wallet'
        ? `Refund ฿${amount} to wallet automatically`
        : `Collect ฿${amount} less from customer`,
    };
  }

  return {
    newTotal,
    diff,
    kind: 'same',
    toneClass: 'text-gray-700 bg-gray-50 border-gray-100',
    message: 'Same price',
  };
}

export function buildOrderItemsPayload(items) {
  return (items || []).map((item) => ({
    menu_item_id: item.menu_item_id || item.id || null,
    name: item.name || item.menu_name || item.item_name || '',
    quantity: Math.max(1, Number.parseInt(item.quantity || 1, 10) || 1),
    price: Number(item.price || item.unit_price || 0) || 0,
    selected_options: item.selected_options || [],
    note: item.note || '',
  }));
}

export function validateOrderItemsPayload(items) {
  if (!Array.isArray(items) || !items.length) {
    return { ok: false, error: 'order_items_required' };
  }

  for (const item of items) {
    if (!item?.menu_item_id) {
      return { ok: false, error: 'menu_item_id_required' };
    }
    if (!String(item.name || '').trim()) {
      return { ok: false, error: 'item_name_required' };
    }
    if (!Number.isFinite(Number(item.quantity)) || Number(item.quantity) < 1) {
      return { ok: false, error: 'quantity_invalid' };
    }
    if (!Number.isFinite(Number(item.price)) || Number(item.price) < 0) {
      return { ok: false, error: 'price_invalid' };
    }
  }

  return { ok: true, error: '' };
}
