import assert from "node:assert/strict";
import {parseVMixStatus,readVMixStatus} from "../core/vmix-status.mjs";

const xml=`<?xml version="1.0" encoding="utf-8"?>
<vmix><version>28.0</version><active>2</active><preview>1</preview>
<inputs>
<input key="cam-1" number="1" type="Capture" state="Running">主机位 &amp; 全景</input>
<input key="cam-2" number="2" type="Capture" state="Running">客机位</input>
<input key="cam-2" number="3" type="Capture">重复</input>
<input key="invalid" number="oops">坏输入</input>
</inputs></vmix>`;
const parsed=parseVMixStatus(xml);
assert.equal(parsed.active,2);
assert.equal(parsed.preview,1);
assert.equal(parsed.inputs.length,2);
assert.deepEqual(parsed.inputs.map(x=>x.title),["主机位 & 全景","客机位"]);
assert.equal(parsed.inputs[0].key,"cam-1");
assert.throws(()=>parseVMixStatus("<html/>"),/INVALID_VMIX_STATUS/);
assert.throws(()=>parseVMixStatus("x".repeat(2_000_001)),/INVALID_VMIX_STATUS/);
const good=await readVMixStatus({health:async()=>({ok:true,body:xml})});
assert.equal(good.ok,true);
assert.equal(good.status.inputs.length,2);
const disconnected=await readVMixStatus({health:async()=>({ok:false,code:"VMIX_DISCONNECTED"})});
assert.equal(disconnected.code,"VMIX_DISCONNECTED");
const malformed=await readVMixStatus({health:async()=>({ok:true,body:"bad"})});
assert.equal(malformed.code,"VMIX_INVALID_XML");
console.log("SAGI VMIX STATUS SELFTEST PASS");
