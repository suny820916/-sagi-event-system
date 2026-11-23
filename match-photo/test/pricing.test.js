const test=require('node:test');
const assert=require('node:assert/strict');
const {quote}=require('../lib/pricing');

test('SAGI PHOTO pricing ladder',()=>{
  assert.equal(quote(1).priceFen,500);
  assert.equal(quote(2).priceFen,1000);
  assert.equal(quote(3).priceFen,1500);
  assert.equal(quote(5).priceFen,1500);
  assert.equal(quote(6).priceFen,2900);
  assert.equal(quote(20).priceFen,2900);
  assert.equal(quote(21).priceFen,9900);
});
test('reject empty selection',()=>assert.throws(()=>quote(0)));
