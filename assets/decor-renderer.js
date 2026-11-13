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
function drawDecorSprite(s,nx,ny,shear=0,smooth=false){
 if(decorRenderer){decorRenderer.sprite(s,nx,ny,shear,smooth);return}
 if(!shear&&!smooth){blitSpr(s,nx,ny);return}
 ctx.save();ctx.imageSmoothingEnabled=smooth;ctx.translate(nx*PX,ny*PX);ctx.transform(1,0,shear,1,0,0);blitSpr(s,0,0);ctx.restore();
}
function drawDecorSlice(s,row,dx,dy,smooth){
 if(decorRenderer){decorRenderer.slice(s,0,row,s.c.width,1,dx,dy,s.c.width*PX,PX,0,0,smooth);return}
 ctx.save();ctx.imageSmoothingEnabled=smooth;ctx.drawImage(s.c,0,row,s.c.width,1,dx,dy,s.c.width*PX,PX);ctx.restore();
}
