// บีบอัดรูปในเบราว์เซอร์ก่อนอัปโหลด (canvas → WebP/JPEG)
// ใช้กับรูปโฆษณา: ถ้าไฟล์เกินขนาด/ใหญ่เกินจอ → ย่อด้านยาวสุด + ลดคุณภาพทีละขั้นจนต่ำกว่า maxBytes

/** ขนาดใหม่ที่ด้านยาวสุดไม่เกิน maxDim (คงอัตราส่วน, ไม่ขยาย) */
export function fitWithin(width, height, maxDim) {
  const w = Math.max(1, Math.round(width));
  const h = Math.max(1, Math.round(height));
  const longest = Math.max(w, h);
  if (longest <= maxDim) return { width: w, height: h };
  const scale = maxDim / longest;
  return { width: Math.max(1, Math.round(w * scale)), height: Math.max(1, Math.round(h * scale)) };
}

/** ต้องบีบไหม: ไฟล์เกิน maxBytes หรือด้านยาวเกิน maxDim (GIF ไม่บีบ — จะเสียภาพเคลื่อนไหว) */
export function needsCompression({ type, size, width, height }, { maxBytes, maxDim }) {
  if (type === 'image/gif') return false;
  return size > maxBytes || Math.max(width || 0, height || 0) > maxDim;
}

const QUALITY_STEPS = [0.86, 0.78, 0.7, 0.6, 0.5];

function _canvasToBlob(canvas, type, quality) {
  return new Promise((resolve) => canvas.toBlob(resolve, type, quality));
}

async function _decode(file) {
  if (typeof createImageBitmap === 'function') {
    try {
      return await createImageBitmap(file);
    } catch (_) {}
  }
  return await new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(url);
      resolve(img);
    };
    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('อ่านไฟล์รูปไม่ได้'));
    };
    img.src = url;
  });
}

/**
 * คืน { file, compressed, originalSize, finalSize }
 * - ไม่ต้องบีบ → คืนไฟล์เดิม
 * - บีบแล้วยังเกิน maxBytes → throw
 */
export async function compressImageIfNeeded(file, { maxBytes = 2 * 1024 * 1024, maxDim = 1600 } = {}) {
  let img;
  try {
    img = await _decode(file);
  } catch (_) {
    throw new Error('เบราว์เซอร์อ่านไฟล์รูปนี้ไม่ได้ (เช่น HEIC จาก iPhone) — แปลงเป็น JPG/PNG ก่อนอัปโหลด');
  }
  const srcW = img.width || img.naturalWidth;
  const srcH = img.height || img.naturalHeight;

  if (!needsCompression({ type: file.type, size: file.size, width: srcW, height: srcH }, { maxBytes, maxDim })) {
    img.close?.();
    return { file, compressed: false, originalSize: file.size, finalSize: file.size };
  }

  // WebP เก็บความโปร่งใสได้; เบราว์เซอร์ที่ไม่รองรับจะคืน PNG → ใช้ JPEG แทน
  let type = 'image/webp';
  let dim = maxDim;
  let best = null;

  for (let round = 0; round < 4 && !best; round++) {
    const { width, height } = fitWithin(srcW, srcH, dim);
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    const g = canvas.getContext('2d');
    if (type === 'image/jpeg') {
      g.fillStyle = '#ffffff';
      g.fillRect(0, 0, width, height);
    }
    g.imageSmoothingQuality = 'high';
    g.drawImage(img, 0, 0, width, height);

    for (const q of QUALITY_STEPS) {
      let blob = await _canvasToBlob(canvas, type, q);
      // ไม่รองรับ WebP (ได้ PNG กลับมา) หรือ encode ไม่ได้ (null) → เปลี่ยนเป็น JPEG
      if (type === 'image/webp' && (!blob || blob.type !== type)) {
        type = 'image/jpeg';
        // เติมพื้นขาวใต้ส่วนโปร่งใส (JPEG ไม่มี alpha) แล้วคืนโหมดวาดปกติ
        g.globalCompositeOperation = 'destination-over';
        g.fillStyle = '#ffffff';
        g.fillRect(0, 0, width, height);
        g.globalCompositeOperation = 'source-over';
        blob = await _canvasToBlob(canvas, type, q);
      }
      if (blob && blob.size <= maxBytes) {
        best = blob;
        break;
      }
    }
    dim = Math.round(dim * 0.75);
  }
  img.close?.();

  if (!best) throw new Error('บีบอัดรูปแล้วยังเกินขนาดที่กำหนด — ลองใช้รูปที่เล็กลง');

  const ext = type === 'image/webp' ? 'webp' : 'jpg';
  const name = (file.name || 'banner').replace(/\.[^.]+$/, '') + '.' + ext;
  const out = new File([best], name, { type });
  return { file: out, compressed: true, originalSize: file.size, finalSize: out.size };
}
