'use strict';

const PRODUCTS = Object.freeze({
  SINGLE: { code: 'single', name: '单张高清原图', priceFen: 500 },
  FIVE: { code: 'five', name: '5张精选', priceFen: 1500 },
  PERSONAL: { code: 'personal', name: '个人整场精选包（最多20张）', priceFen: 2900 },
  TEAM: { code: 'team', name: '全队整场照片包', priceFen: 9900 }
});

function quote(count) {
  const n = Number(count);
  if (!Number.isInteger(n) || n < 1) throw new Error('至少选择1张照片');
  if (n === 1) return { ...PRODUCTS.SINGLE, count: n };
  if (n === 2) return { code: 'single-2', name: '2张高清原图', priceFen: 1000, count: n };
  if (n <= 5) return { ...PRODUCTS.FIVE, count: n };
  if (n <= 20) return { ...PRODUCTS.PERSONAL, count: n };
  return { ...PRODUCTS.TEAM, count: n };
}

module.exports = { PRODUCTS, quote };
