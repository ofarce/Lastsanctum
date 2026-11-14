'use strict';
// Les sprites restent triés avec les unités. Chaque groupe de décor est dessiné
// en une passe GPU, puis recopié avant l'unité suivante pour conserver l'occlusion.
let decorRenderer=null;
class DecorRenderer{
 constructor(objects){
  this.canvas=document.createElement('canvas');
  const gl=this.gl=this.canvas.getContext('webgl',{alpha:false,premultipliedAlpha:true,antialias:false,depth:false,stencil:false});
  if(!gl)throw new Error('WebGL indisponible');
  const sprites=new Set();for(const o of objects)if(o.spr){sprites.add(o.spr);if(o.spr.foliage)sprites.add(o.spr.foliage);if(o.flag)sprites.add(o.flag.spr)}
  this.entries=new Map();const width=Math.min(2048,gl.getParameter(gl.MAX_TEXTURE_SIZE));let x=2,y=2,row=0;
  for(const s of sprites){if(x+s.c.width+2>width){x=2;y+=row+4;row=0}this.entries.set(s,{x,y});x+=s.c.width+4;row=Math.max(row,s.c.height)}
  const height=y+row+2;if(height>gl.getParameter(gl.MAX_TEXTURE_SIZE))throw new Error('Atlas du décor trop grand');
  const atlas=document.createElement('canvas');atlas.width=width;atlas.height=height;const ag=atlas.getContext('2d');
  for(const[s,p]of this.entries)ag.drawImage(s.c,p.x,p.y);
  const shader=(type,code)=>{const s=gl.createShader(type);gl.shaderSource(s,code);gl.compileShader(s);if(!gl.getShaderParameter(s,gl.COMPILE_STATUS))throw new Error(gl.getShaderInfoLog(s));return s};
  const program=this.program=gl.createProgram();
  gl.attachShader(program,shader(gl.VERTEX_SHADER,`attribute vec2 a_position;attribute vec2 a_uv;attribute float a_smooth;uniform vec2 u_screen;varying vec2 v_uv;varying float v_smooth;void main(){gl_Position=vec4(a_position.x/u_screen.x*2.0-1.0,1.0-a_position.y/u_screen.y*2.0,0.0,1.0);v_uv=a_uv;v_smooth=a_smooth;}`));
  gl.attachShader(program,shader(gl.FRAGMENT_SHADER,`precision highp float;uniform sampler2D u_texture;uniform sampler2D u_smoothTexture;varying vec2 v_uv;varying float v_smooth;void main(){if(v_smooth>0.5)gl_FragColor=texture2D(u_smoothTexture,v_uv);else gl_FragColor=texture2D(u_texture,v_uv);}`));
  gl.linkProgram(program);if(!gl.getProgramParameter(program,gl.LINK_STATUS))throw new Error(gl.getProgramInfoLog(program));gl.useProgram(program);
  this.buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,this.buffer);
  for(const[name,size,offset]of [['a_position',2,0],['a_uv',2,8],['a_smooth',1,16]]){const a=gl.getAttribLocation(program,name);gl.enableVertexAttribArray(a);gl.vertexAttribPointer(a,size,gl.FLOAT,false,20,offset)}
  this.screen=gl.getUniformLocation(program,'u_screen');gl.uniform1i(gl.getUniformLocation(program,'u_texture'),0);gl.uniform1i(gl.getUniformLocation(program,'u_smoothTexture'),1);
  this.texture=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,this.texture);gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL,true);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,atlas);
  gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
  gl.enable(gl.BLEND);gl.blendFunc(gl.ONE,gl.ONE_MINUS_SRC_ALPHA);gl.clearColor(0,0,0,0);
  const debug=gl.getExtension('WEBGL_debug_renderer_info'),backend=debug?gl.getParameter(debug.UNMASKED_RENDERER_WEBGL):'';
  // Garder la résolution native sur GPU matériel ; limiter le remplissage
  // sur les moteurs logiciels, dont le coût augmente avec chaque pixel.
  this.renderScale=/swiftshader|llvmpipe|software/i.test(backend)?1/3:1;this.atlasWidth=width;this.atlasHeight=height;this.vertices=[];this.resetBounds();
  gl.activeTexture(gl.TEXTURE1);this.smoothTexture=this.makeTexture(atlas,gl.LINEAR);gl.bindTexture(gl.TEXTURE_2D,this.smoothTexture);gl.activeTexture(gl.TEXTURE0);gl.bindTexture(gl.TEXTURE_2D,this.texture);
  this.layer=document.createElement('canvas');this.layerContext=this.layer.getContext('2d',{willReadFrequently:true});this.layerTexture=this.makeTexture();this.groundTexture=this.makeTexture(PW.ground);
  this.canvas.id='decor-scene';Object.assign(this.canvas.style,{position:'fixed',inset:'0',width:'100vw',height:'100vh',pointerEvents:'none',zIndex:'1'});document.body.appendChild(this.canvas);
  this.canvas.addEventListener('webglcontextlost',ev=>{ev.preventDefault();if(decorRenderer===this){decorRenderer=null;this.canvas.style.display='none';canvas.style.opacity='1'}});
 }
 resetBounds(){this.left=Infinity;this.top=Infinity;this.right=-Infinity;this.bottom=-Infinity}
 begin(){const width=Math.ceil(W*dpr*this.renderScale),height=Math.ceil(H*dpr*this.renderScale);if(this.canvas.width!==width||this.canvas.height!==height){this.canvas.width=width;this.canvas.height=height}this.gl.viewport(0,0,width,height);this.gl.uniform2f(this.screen,W,H);this.vertices.length=0;this.resetBounds();this.canvas.style.display=PIXEL?'block':'none';canvas.style.opacity=PIXEL?'0':'1';this.canvas.style.imageRendering=this.renderScale<1?'pixelated':'auto';this.gl.clearColor(11/255,18/255,14/255,1);this.gl.clear(this.gl.COLOR_BUFFER_BIT)}
 sprite(s,nx,ny,shear=0,smooth=false){this.slice(s,0,0,s.c.width,s.c.height,(nx-s.ax)*PX,(ny-s.ay)*PX,s.c.width*PX,s.c.height*PX,shear,ny*PX,smooth)}
 slice(s,sx,sy,sw,sh,dx,dy,dw,dh,shear=0,pivot=0,smooth=false){
  const p=this.entries.get(s);if(!p)return;
  const topShift=(dy-pivot)*shear,bottomShift=(dy+dh-pivot)*shear;
  const x0=dx+topShift,x1=x0+dw,x2=dx+bottomShift,x3=x2+dw;
  this.left=Math.min(this.left,x0,x2);this.right=Math.max(this.right,x1,x3);this.top=Math.min(this.top,dy);this.bottom=Math.max(this.bottom,dy+dh);
  const u0=(p.x+sx)/this.atlasWidth,u1=(p.x+sx+sw)/this.atlasWidth,v0=(p.y+sy)/this.atlasHeight,v1=(p.y+sy+sh)/this.atlasHeight,m=smooth?1:0;
  this.vertices.push(x0,dy,u0,v0,m,x2,dy+dh,u0,v1,m,x1,dy,u1,v0,m,x1,dy,u1,v0,m,x2,dy+dh,u0,v1,m,x3,dy+dh,u1,v1,m);
 }
 flush(){
  if(!this.vertices.length)return;
  const gl=this.gl;gl.bindBuffer(gl.ARRAY_BUFFER,this.buffer);gl.bufferData(gl.ARRAY_BUFFER,new Float32Array(this.vertices),gl.DYNAMIC_DRAW);gl.drawArrays(gl.TRIANGLES,0,this.vertices.length/5);
  this.vertices.length=0;this.resetBounds();
 }
 makeTexture(source,filter=this.gl.NEAREST){const gl=this.gl;if(source&&Math.max(source.width,source.height)>gl.getParameter(gl.MAX_TEXTURE_SIZE))throw new Error('Texture trop grande pour ce GPU');const t=gl.createTexture();gl.bindTexture(gl.TEXTURE_2D,t);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,filter);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,filter);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);if(source)gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,source);gl.bindTexture(gl.TEXTURE_2D,this.texture);return t}
 textureQuad(texture,tw,th,sx,sy,sw,sh,dx,dy,dw,dh){
  this.flush();const gl=this.gl,u0=sx/tw,u1=(sx+sw)/tw,v0=sy/th,v1=(sy+sh)/th;
  const data=new Float32Array([dx,dy,u0,v0,0,dx,dy+dh,u0,v1,0,dx+dw,dy,u1,v0,0,dx+dw,dy,u1,v0,0,dx,dy+dh,u0,v1,0,dx+dw,dy+dh,u1,v1,0]);
  gl.bindTexture(gl.TEXTURE_2D,texture);gl.bindBuffer(gl.ARRAY_BUFFER,this.buffer);gl.bufferData(gl.ARRAY_BUFFER,data,gl.DYNAMIC_DRAW);gl.drawArrays(gl.TRIANGLES,0,6);
  gl.bindTexture(gl.TEXTURE_2D,this.texture);
 }
 portal(frame,nx,ny){const image=PORTAL.atlas;if(!this.portalTexture)this.portalTexture=this.makeTexture(image);this.textureQuad(this.portalTexture,image.naturalWidth,image.naturalHeight,(frame%16)*PortalKit.W,Math.floor(frame/16)*PortalKit.H,PortalKit.W,PortalKit.H,(nx-PortalKit.OX)*PX,(ny-PortalKit.OY)*PX,PortalKit.W*PX,PortalKit.H*PX)}
 ground(sx,sy,sw,sh,dx,dy,dw,dh){this.textureQuad(this.groundTexture,PW.ground.width,PW.ground.height,sx,sy,sw,sh,dx,dy,dw,dh)}
 capture(x=0,y=0,w=W,h=H){
  const left=Math.max(0,Math.floor(x*dpr)),top=Math.max(0,Math.floor(y*dpr)),right=Math.min(canvas.width,Math.ceil((x+w)*dpr)),bottom=Math.min(canvas.height,Math.ceil((y+h)*dpr));
  if(right<=left||bottom<=top)return;
  const width=right-left,height=bottom-top;if(this.layer.width!==width||this.layer.height!==height){this.layer.width=width;this.layer.height=height}else this.layerContext.clearRect(0,0,width,height);
  this.layerContext.drawImage(canvas,left,top,width,height,0,0,width,height);
  const gl=this.gl;gl.bindTexture(gl.TEXTURE_2D,this.layerTexture);gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,this.layer);gl.bindTexture(gl.TEXTURE_2D,this.texture);
  this.textureQuad(this.layerTexture,width,height,0,0,width,height,left/dpr,top/dpr,width/dpr,height/dpr);
  ctx.clearRect(left/dpr,top/dpr,width/dpr,height/dpr);
 }

}
function useCanvasDecor(){if(decorRenderer){decorRenderer.canvas.style.display='none';decorRenderer=null}canvas.style.opacity='1'}
// Le Canvas 2D est le chemin par défaut, y compris dans les navigateurs intégrés.
// Le rendu WebGL reste disponible explicitement avec ?renderer=webgl.
function initDecorRenderer(){if(new URLSearchParams(location.search).get('renderer')!=='webgl'){useCanvasDecor();return}try{decorRenderer=new DecorRenderer(PW.objs)}catch(error){console.warn('Décor : rendu Canvas de secours.',error);useCanvasDecor()}}
function flushDecor(){if(decorRenderer&&PIXEL)decorRenderer.flush()}
function captureDecorLayer(x,y,w,h){if(decorRenderer&&PIXEL)decorRenderer.capture(x,y,w,h)}
// Cache Canvas 2D des sprites de décor déjà agrandis à l'échelle PX (et, pour le feuillage, déjà cisaillés par le vent).
// Agrandir et cisailler avec lissage à chaque image coûtait ~40 ms en jungle (≈500 arbres visibles) ; une copie 1:1 est quasi gratuite.
// Le cisaillement est quantifié au tiers de pixel natif (PX/3 px écran) en haut du sprite : le balancement reste visuellement continu.
// Tous les sprites passés ici sont statiques (décor construit une fois). Budget mémoire borné : au-delà, dessin direct.
const DECOR_CACHE={px:0,map:new Map(),bytes:0,budget:80e6};
function decorVariant(s,shear,smooth){
 if(DECOR_CACHE.px!==PX){DECOR_CACHE.px=PX;DECOR_CACHE.map.clear();DECOR_CACHE.bytes=0}
 let e=DECOR_CACHE.map.get(s);if(!e){e=new Map();DECOR_CACHE.map.set(s,e)}
 const top=s.ay*PX,qs=PX/3,n=shear?Math.round(shear*top/qs):0,key=(smooth?'s':'n')+n;let v=e.get(key);if(v)return v;
 const w=s.c.width*PX,h=s.c.height*PX,sh=top?n*qs/top:0;
 const minX=-s.ax*PX+Math.min(-sh*top,sh*(h-top)),maxX=(s.c.width-s.ax)*PX+Math.max(-sh*top,sh*(h-top)),ox=Math.ceil(-minX),cw=Math.ceil(maxX)+ox;
 if(DECOR_CACHE.bytes+cw*h*4>DECOR_CACHE.budget)return null;
 const c=document.createElement('canvas');c.width=cw;c.height=h;const g=c.getContext('2d');g.imageSmoothingEnabled=smooth;
 g.translate(ox,top);g.transform(1,0,sh,1,0,0);g.drawImage(s.c,-s.ax*PX,-top,w,h);
 v={c,ox,oy:top};e.set(key,v);DECOR_CACHE.bytes+=cw*h*4;return v}
// Arbre au vent : tronc (fixe, net) + feuillage (cisaillé, lissé) fusionnés en une seule image par niveau de vent.
function treeVariant(t,shear){
 if(DECOR_CACHE.px!==PX){DECOR_CACHE.px=PX;DECOR_CACHE.map.clear();DECOR_CACHE.bytes=0}
 let e=DECOR_CACHE.map.get(t);if(!e){e=new Map();DECOR_CACHE.map.set(t,e)}
 const f=t.foliage,ftop=f.ay*PX,qs=PX/3,n=shear?Math.round(shear*ftop/qs):0,key='t'+n;let v=e.get(key);if(v)return v;
 const sh=ftop?n*qs/ftop:0,fh=f.c.height*PX,top=Math.max(t.ay,f.ay)*PX,bot=Math.max(t.c.height-t.ay,f.c.height-f.ay)*PX;
 const minX=Math.min(-t.ax*PX,-f.ax*PX+Math.min(-sh*ftop,sh*(fh-ftop))),maxX=Math.max((t.c.width-t.ax)*PX,(f.c.width-f.ax)*PX+Math.max(-sh*ftop,sh*(fh-ftop)));
 const ox=Math.ceil(-minX),cw=Math.ceil(maxX)+ox,ch=Math.ceil(top+bot);
 if(DECOR_CACHE.bytes+cw*ch*4>DECOR_CACHE.budget)return null;
 const c=document.createElement('canvas');c.width=cw;c.height=ch;const g=c.getContext('2d');
 g.translate(ox,top);g.imageSmoothingEnabled=false;g.drawImage(t.c,-t.ax*PX,-t.ay*PX,t.c.width*PX,t.c.height*PX);
 g.imageSmoothingEnabled=true;g.transform(1,0,sh,1,0,0);g.drawImage(f.c,-f.ax*PX,-ftop,f.c.width*PX,fh);
 v={c,ox,oy:top};e.set(key,v);DECOR_CACHE.bytes+=cw*ch*4;return v}
// Préchauffage : construit tous les niveaux de vent des arbres et les sprites de décor pendant les temps morts,
// pour éviter un à-coup la première fois qu'une zone de jungle entre à l'écran. Relancé après un changement de zoom.
function warmDecorCache(){if(decorRenderer||!PIXEL)return;const px=PX,todo=[],seen=new Set();
 for(const o of PW.objs){if(!o.spr||seen.has(o.spr))continue;seen.add(o.spr);if(o.wind){const sp=WIND_TREES[o.wind],ftop=o.spr.foliage.ay*PX,qs=PX/3,m=Math.ceil(sp.amplitude/sp.height*ftop/qs);for(let n=-m;n<=m;n++)todo.push([o.spr,n*qs/ftop,true])}else todo.push([o.spr,0,false])}
 const step=dl=>{if(PX!==px)return;const end=performance.now()+8;while(todo.length&&performance.now()<end&&(!dl||dl.timeRemaining()>1)){const[s,sh,tree]=todo.pop();if(!(tree?treeVariant(s,sh):decorVariant(s,0,false)))return}if(todo.length)schedule()};
 const schedule=()=>typeof requestIdleCallback==='function'?requestIdleCallback(step,{timeout:500}):setTimeout(step,30);schedule()}
function drawDecorSprite(s,nx,ny,shear=0,smooth=false){
 if(decorRenderer){decorRenderer.sprite(s,nx,ny,shear,smooth);return}
 const v=decorVariant(s,shear,smooth);if(v){ctx.drawImage(v.c,nx*PX-v.ox,ny*PX-v.oy);return}
 if(!shear&&!smooth){blitSpr(s,nx,ny);return}
 ctx.save();ctx.imageSmoothingEnabled=smooth;ctx.translate(nx*PX,ny*PX);ctx.transform(1,0,shear,1,0,0);blitSpr(s,0,0);ctx.restore();
}
function drawDecorSlice(s,row,dx,dy,smooth){
 if(decorRenderer){decorRenderer.slice(s,0,row,s.c.width,1,dx,dy,s.c.width*PX,PX,0,0,smooth);return}
 ctx.save();ctx.imageSmoothingEnabled=smooth;ctx.drawImage(s.c,0,row,s.c.width,1,dx,dy,s.c.width*PX,PX);ctx.restore();
}
