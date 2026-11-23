// V4.33 LAN-first boot dependency gate. Optional user-triggered imports are
// reported separately; no overseas resource may be required to render live UI.
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {dirname,resolve} from 'node:path';
import assert from 'node:assert/strict';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
for(const name of ['v45-lan.html','vmix-v45-lan.html']){
 const html=readFileSync(resolve(root,name),'utf8');
 const required=[];
 for(const match of html.matchAll(/<(?:script|link)\\b[^>]*\\b(?:src|href)\\s*=\\s*['\"](https?:\\/\\/[^'\"]+)/gi)) required.push(match[1]);
 for(const match of html.matchAll(/@import\\s+(?:url\\()?\\s*['\"]?(https?:\\/\\/[^'\"\\s)]+)/gi)) required.push(match[1]);
 assert.deepEqual(required,[],name+' requires remote script/style on LAN-only boot');
 const optional=[...html.matchAll(/import\\s*\\(\\s*['\"](https?:\\/\\/[^'\"]+)/g)].map(x=>x[1]);
 console.log(name+': offline boot dependency PASS; optional remote imports='+optional.length);
 if(optional.length) console.log('OPTIONAL REMOTE DEPENDENCIES (localize before commercial offline certification): '+optional.join(', '));
}
