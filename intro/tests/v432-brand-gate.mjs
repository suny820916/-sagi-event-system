import fs from 'node:fs';
function assert(ok,msg){if(!ok)throw new Error(msg)}
const html=fs.readFileSync(new URL('../vmix-v45-lan.html',import.meta.url),'utf8');
const control=fs.readFileSync(new URL('../v45-lan.html',import.meta.url),'utf8');
assert(html.includes('sagiBrandWord')&&html.includes('sagiBrandA')&&html.includes('sagiBrandSub'),'SAGI brand element missing');
assert((html.match(/class="sagiBrandA"/g)||[]).length>=3,'SAGI brand element not applied across event/replay family');
assert(html.includes('FOOTBALL'),'SAGI FOOTBALL lockup missing');
assert(html.includes('#ff1a1a'),'SAGI signature red dot token missing');
assert(control.includes('sagiControlLogo')&&control.includes('sagiControlA')&&control.includes('#ff1a1a'),'SAGI control-room logo element missing');
assert(html.includes('#e33440'),'match red-card token missing');
assert('#ff1a1a'!=='#e33440','brand red dot and referee red card must remain distinct');

// Validate the actual style bindings, not merely the presence of two color literals.
const brandDotRule=html.match(/\.sagiBrandA\s+i\s*\{([^}]*)\}/);
assert(brandDotRule && /background\s*:\s*#ff1a1a\b/i.test(brandDotRule[1]),'SAGI A red dot must retain its own brand color');
const redEventRule=html.match(/\.eventCard\.red\s*\{([^}]*)\}/);
assert(redEventRule && /--eventAccent\s*:\s*#e33440\b/i.test(redEventRule[1]),'referee red event must retain independent match red');
assert(/function\s+redCardsHtml\s*\(/.test(html) && html.includes('class="sbRedCard"'),'scoreboard red-card indicator renderer missing');
assert(/\.sbRedCard\s*\{/.test(html),'scoreboard red-card indicator CSS missing');

// The broadcast overlay must keep both independently styled tokens available.
assert(html.includes('sagiBrandA')&&html.includes('#ff1a1a')&&html.includes('#e33440'),'brand/red-card separation regression');
assert(!/<img[^>]+class="[^"]*sagiBrand/i.test(html),'brand identity must not depend on external image loading');
console.log('V4.32 SAGI BRAND GATE PASS');
