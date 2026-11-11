(function(){
  function loadImage(file){
    return new Promise(function(resolve,reject){
      const url=URL.createObjectURL(file);
      const img=new Image();
      img.onload=function(){
        setTimeout(function(){URL.revokeObjectURL(url)},30000);
        resolve(img);
      };
      img.onerror=function(){URL.revokeObjectURL(url);reject(new Error('图片读取失败'))};
      img.src=url;
    });
  }

  function safeHex(v,fallback){
    return /^#[0-9a-f]{6}$/i.test(String(v||''))?v:fallback;
  }

  function wrap(ctx,text,maxWidth,maxLines){
    const chars=Array.from(String(text||''));
    const lines=[];
    let line='';
    for(let i=0;i<chars.length;i++){
      const test=line+chars[i];
      if(ctx.measureText(test).width>maxWidth&&line){
        lines.push(line);
        line=chars[i];
        if(lines.length>=maxLines-1)break;
      }else line=test;
    }
    if(line&&lines.length<maxLines)lines.push(line);
    return lines;
  }

  function coverCrop(ctx,img,W,H,focus){
    const iw=img.naturalWidth||img.width;
    const ih=img.naturalHeight||img.height;
    const scale=Math.max(W/iw,H/ih);
    const sw=W/scale,sh=H/scale;
    let sx=(iw-sw)/2,sy=(ih-sh)/2;
    if(focus==='top')sy=0;
    if(focus==='bottom')sy=ih-sh;
    if(focus==='left')sx=0;
    if(focus==='right')sx=iw-sw;
    sx=Math.max(0,Math.min(iw-sw,sx));
    sy=Math.max(0,Math.min(ih-sh,sy));
    ctx.drawImage(img,sx,sy,sw,sh,0,0,W,H);
  }

  function drawGrade(ctx,img,W,H,focus,grade){
    ctx.save();
    if(grade==='warm')ctx.filter='brightness(.90) contrast(1.10) saturate(1.10)';
    else if(grade==='clean')ctx.filter='brightness(.96) contrast(1.05) saturate(.98)';
    else ctx.filter='brightness(.84) contrast(1.16) saturate(1.12)';
    coverCrop(ctx,img,W,H,focus||'center');
    ctx.restore();
  }

  function vignette(ctx,W,H,strength){
    const g=ctx.createRadialGradient(W*.5,H*.45,Math.min(W,H)*.2,W*.5,H*.5,Math.max(W,H)*.8);
    g.addColorStop(0,'rgba(0,0,0,0)');
    g.addColorStop(1,'rgba(0,0,0,'+String(strength||.5)+')');
    ctx.fillStyle=g;
    ctx.fillRect(0,0,W,H);
  }

  function extractOffer(text){
    const t=String(text||'');
    const patterns=[
      /¥\s*\d+(?:\.\d+)?/i,/￥\s*\d+(?:\.\d+)?/i,/\d+(?:\.\d+)?\s*元/,
      /\d+(?:\.\d+)?\s*折/,/第二份半价/,/买一送一/,/免费体验/,/限时优惠/
    ];
    for(let i=0;i<patterns.length;i++){
      const m=t.match(patterns[i]);
      if(m&&m[0])return m[0];
    }
    return '';
  }

  function roundRect(ctx,x,y,w,h,r){
    ctx.beginPath();
    if(typeof ctx.roundRect==='function')ctx.roundRect(x,y,w,h,r);
    else ctx.rect(x,y,w,h);
  }

  function lineText(ctx,text,x,y,maxWidth,maxLines,lineHeight){
    const lines=wrap(ctx,text,maxWidth,maxLines);
    for(let i=0;i<lines.length;i++)ctx.fillText(lines[i],x,y+i*lineHeight);
    return lines.length;
  }

  function colors(pack){
    const p=(pack&&pack.palette)||{};
    return {
      text:safeHex(p.text,'#FFFFFF'),
      accent:safeHex(p.accent,'#E7C568'),
      ink:'#0B0B0C',
      paper:'#F1EEE6'
    };
  }

  function drawEditorial(ctx,img,pack,W,H,is916,profile){
    const c=colors(pack);
    const pad=W*.07;
    const brand=((profile&&profile.merchant_name)||'SAGI AI LOCAL').toUpperCase();
    const headline=is916?(pack.coverHeadline||pack.headline):pack.headline;
    const offer=extractOffer((pack.brief||'')+' '+headline);

    drawGrade(ctx,img,W,H,pack.cropFocus,'warm');
    vignette(ctx,W,H,.58);

    const g=ctx.createLinearGradient(0,H*.38,0,H);
    g.addColorStop(0,'rgba(0,0,0,0)');
    g.addColorStop(.55,'rgba(0,0,0,.18)');
    g.addColorStop(1,'rgba(0,0,0,.94)');
    ctx.fillStyle=g;ctx.fillRect(0,H*.3,W,H*.7);

    ctx.textBaseline='top';
    ctx.fillStyle='rgba(255,255,255,.75)';
    ctx.font='700 '+Math.round(W*.021)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    ctx.fillText('SAGI LOCAL / '+((profile&&profile.industry)||'LOCAL BUSINESS'),pad,H*.055);

    ctx.fillStyle=c.accent;
    ctx.fillRect(pad,H*(is916 ? .61:.57),W*.12,Math.max(5,W*.006));

    ctx.fillStyle=c.text;
    ctx.font='900 '+Math.round(W*(is916 ? .082:.075))+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    const y=H*(is916 ? .64:.61);
    const n=lineText(ctx,headline,pad,y,W*.78,is916?3:2,W*.10);

    ctx.fillStyle='rgba(255,255,255,.78)';
    ctx.font='500 '+Math.round(W*.030)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    lineText(ctx,pack.subheadline||'',pad,y+n*W*.10+W*.02,W*.70,2,W*.043);

    if(offer){
      ctx.textAlign='right';
      ctx.fillStyle=c.accent;
      ctx.font='900 '+Math.round(W*.062)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
      ctx.fillText(offer,W-pad,H*(is916 ? .835:.84));
      ctx.textAlign='left';
    }

    ctx.fillStyle='rgba(255,255,255,.65)';
    ctx.font='600 '+Math.round(W*.024)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    ctx.fillText(brand,pad,H*.92);
    ctx.fillStyle=c.accent;
    ctx.fillRect(W-pad-W*.18,H*.92+W*.008,W*.18,Math.max(3,W*.004));
  }

  function drawSplit(ctx,img,pack,W,H,is916,profile){
    const c=colors(pack);
    const pad=W*.07;
    const brand=((profile&&profile.merchant_name)||'SAGI AI LOCAL').toUpperCase();
    const headline=is916?(pack.coverHeadline||pack.headline):pack.headline;
    const offer=extractOffer((pack.brief||'')+' '+headline);
    const split=is916 ? .61:.60;

    ctx.fillStyle=c.ink;ctx.fillRect(0,0,W,H);
    ctx.save();ctx.beginPath();ctx.rect(0,0,W,H*split);ctx.clip();
    drawGrade(ctx,img,W,H*split,pack.cropFocus,'clean');ctx.restore();

    const top=ctx.createLinearGradient(0,0,W,0);
    top.addColorStop(0,'rgba(0,0,0,.45)');top.addColorStop(1,'rgba(0,0,0,0)');
    ctx.fillStyle=top;ctx.fillRect(0,0,W,H*split);

    ctx.textBaseline='top';
    ctx.fillStyle=c.accent;
    ctx.font='800 '+Math.round(W*.022)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    ctx.fillText(brand,pad,H*.05);

    ctx.fillStyle=c.paper;
    ctx.font='900 '+Math.round(W*(is916 ? .070:.063))+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    const y=H*(split+.055);
    const n=lineText(ctx,headline,pad,y,W*.76,is916?3:2,W*.086);

    ctx.fillStyle='rgba(242,239,231,.66)';
    ctx.font='500 '+Math.round(W*.028)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    lineText(ctx,pack.subheadline||'',pad,y+n*W*.086+W*.015,W*.68,2,W*.042);

    if(offer){
      ctx.fillStyle=c.accent;
      ctx.font='900 '+Math.round(W*.058)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
      ctx.fillText(offer,pad,H*.88);
    }

    const cta=pack.cta||'立即了解';
    ctx.font='800 '+Math.round(W*.024)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    const tw=ctx.measureText(cta).width+W*.065;
    roundRect(ctx,W-pad-tw,H*.89,tw,W*.062,W*.031);
    ctx.fillStyle=c.paper;ctx.fill();
    ctx.fillStyle=c.ink;ctx.fillText(cta,W-pad-tw+W*.032,H*.89+W*.018);
  }

  function drawImpact(ctx,img,pack,W,H,is916,profile){
    const c=colors(pack);
    const pad=W*.055;
    const brand=((profile&&profile.merchant_name)||'SAGI AI LOCAL').toUpperCase();
    const headline=is916?(pack.coverHeadline||pack.headline):pack.headline;
    const offer=extractOffer((pack.brief||'')+' '+headline);

    drawGrade(ctx,img,W,H,pack.cropFocus,'impact');
    ctx.fillStyle='rgba(0,0,0,.20)';ctx.fillRect(0,0,W,H);
    vignette(ctx,W,H,.44);

    ctx.save();
    ctx.translate(0,H*.08);ctx.rotate(-.035);
    ctx.fillStyle=c.accent;ctx.fillRect(-W*.04,0,W*.62,W*.085);
    ctx.fillStyle=c.ink;
    ctx.font='900 '+Math.round(W*.034)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    ctx.fillText(((profile&&profile.industry)||'LOCAL DEAL').toUpperCase(),pad,W*.022);
    ctx.restore();

    const panelY=H*(is916 ? .59:.56);
    const g=ctx.createLinearGradient(0,panelY,0,H);
    g.addColorStop(0,'rgba(0,0,0,.08)');
    g.addColorStop(.25,'rgba(0,0,0,.76)');
    g.addColorStop(1,'rgba(0,0,0,.96)');
    ctx.fillStyle=g;ctx.fillRect(0,panelY,W,H-panelY);

    ctx.textBaseline='top';
    ctx.fillStyle='#fff';
    ctx.font='900 '+Math.round(W*(is916 ? .086:.078))+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    const y=H*(is916 ? .65:.62);
    const n=lineText(ctx,headline,pad,y,W*.84,is916?3:2,W*.102);

    if(offer){
      ctx.fillStyle=c.accent;
      ctx.font='900 '+Math.round(W*.075)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
      ctx.fillText(offer,pad,y+n*W*.102+W*.02);
    }

    ctx.fillStyle='rgba(255,255,255,.68)';
    ctx.font='600 '+Math.round(W*.026)+'px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif';
    ctx.fillText(brand,pad,H*.925);

    ctx.strokeStyle='rgba(255,255,255,.24)';
    ctx.lineWidth=Math.max(2,W*.002);
    ctx.strokeRect(pad*.55,pad*.55,W-pad*1.1,H-pad*1.1);
  }

  function render(canvas,img,pack,style,is916,profile){
    const ctx=canvas.getContext('2d');
    const W=canvas.width,H=canvas.height;
    ctx.clearRect(0,0,W,H);
    if(style==='split')drawSplit(ctx,img,pack,W,H,is916,profile);
    else if(style==='impact')drawImpact(ctx,img,pack,W,H,is916,profile);
    else drawEditorial(ctx,img,pack,W,H,is916,profile);
    canvas.dataset.rendered='1';
    canvas.dataset.style=style;
  }

  function canvasToFile(canvas,name){
    return new Promise(function(resolve,reject){
      canvas.toBlob(function(blob){
        if(!blob)return reject(new Error('海报导出失败'));
        resolve(new File([blob],name||'poster.png',{type:'image/png'}));
      },'image/png');
    });
  }

  function download(canvas,name){
    canvas.toBlob(function(blob){
      if(!blob)return;
      const url=URL.createObjectURL(blob);
      const a=document.createElement('a');
      a.href=url;a.download=name||'SAGI_LOCAL.png';
      document.body.appendChild(a);a.click();a.remove();
      setTimeout(function(){URL.revokeObjectURL(url)},5000);
    },'image/png');
  }

  window.SAGI_POSTER={
    loadImage:loadImage,
    render:render,
    canvasToFile:canvasToFile,
    download:download
  };
})();