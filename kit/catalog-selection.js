'use strict';

function catalogSelection(catalog, page) {
  const editions = {
    '2026': { title: 'SAGI 2026 产品画册', last: 33 },
    culture: { title: 'SAGI 足球品牌文化画册', last: 25 }
  };
  if (!Object.hasOwn(editions, catalog)) return null;
  const edition = editions[catalog];
  if (!Number.isInteger(page) || page < 4 || page > edition.last) return null;
  const code = catalog === 'culture' && page <= 5
    ? (page === 4 ? '01A' : '01B')
    : String(page - 3).padStart(2, '0');
  return { catalog, page, code, title: edition.title };
}
