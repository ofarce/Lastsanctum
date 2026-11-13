'use strict';
const CharacterDialogue={active:null,index:0,elapsed:0,returnFocus:null};
function initCharacterDialogue(){
 const panel=document.createElement('section');panel.id='character-dialogue';panel.hidden=true;panel.setAttribute('role','dialog');panel.setAttribute('aria-labelledby','dialogue-name');
 panel.innerHTML='<canvas id="dialogue-portrait" width="128" height="160" aria-hidden="true"></canvas><div class="dialogue-copy"><h2 id="dialogue-name"></h2><p id="dialogue-text" aria-hidden="true"></p><div id="dialogue-announcement" aria-live="polite"></div><div id="dialogue-choices"></div><div class="dialogue-controls"><span>Entrée : suite · Échap : fermer</span><button id="dialogue-next">Suite ▸</button></div></div><button id="dialogue-close" aria-label="Fermer le dialogue">×</button>';
 document.body.append(panel);panel.addEventListener('keydown',ev=>{if(ev.key===' '||ev.key==='Enter')ev.stopPropagation()});
 document.getElementById('dialogue-next').onclick=advanceCharacterDialogue;document.getElementById('dialogue-close').onclick=closeCharacterDialogue;
 addEventListener('keydown',ev=>{if(!CharacterDialogue.active)return;if(ev.key==='Escape'||(ev.key==='Enter'&&ev.target.tagName!=='BUTTON')){ev.preventDefault();ev.stopImmediatePropagation();if(ev.key==='Escape')closeCharacterDialogue();else if(!ev.repeat)advanceCharacterDialogue()}},true);
}
function showCharacterDialogue(dialogue){
 const d=CharacterDialogue;if(!d.active)d.returnFocus=document.activeElement;d.active=dialogue;d.index=0;document.getElementById('character-dialogue').hidden=false;document.getElementById('dialogue-name').textContent=dialogue.name;
 renderCharacterDialogueLine();positionCharacterDialogue();
}
function renderCharacterDialogueLine(){
 const d=CharacterDialogue;d.elapsed=0;document.getElementById('dialogue-text').textContent='';document.getElementById('dialogue-announcement').textContent=d.active.lines[d.index];
 const choices=document.getElementById('dialogue-choices');choices.replaceChildren();
 document.getElementById('dialogue-next').textContent=d.index===d.active.lines.length-1?'Terminer ▸':'Suite ▸';
}
function updateCharacterDialogue(dt){
 const d=CharacterDialogue;if(!d.active)return;d.elapsed+=dt;
 const line=d.active.lines[d.index],count=matchMedia('(prefers-reduced-motion: reduce)').matches?line.length:Math.floor(d.elapsed/0.024),el=document.getElementById('dialogue-text');el.textContent=line.slice(0,count);
 if(count>=line.length&&d.index===d.active.lines.length-1&&!document.getElementById('dialogue-choices').childElementCount){
  for(const choice of d.active.choices||[]){const b=document.createElement('button');b.textContent=choice.label;b.onclick=()=>{if(choice.lines){d.active={...d.active,lines:choice.lines,choices:[]};d.index=0;renderCharacterDialogueLine()}else closeCharacterDialogue()};document.getElementById('dialogue-choices').append(b)}
 }
 positionCharacterDialogue();
}
function positionCharacterDialogue(){
 const d=CharacterDialogue,panel=document.getElementById('character-dialogue');if(!d.active||!panel)return;
 const u=d.active.speaker;if(!u||u.hp<=0||u.hidden){closeCharacterDialogue();return}
 const head=project(u.x,2.8,u.z);
 // Garder la pointe reliée à la tête, même lorsque la bulle est décalée au bord de l’écran.
 const width=panel.offsetWidth,height=panel.offsetHeight,margin=12,gap=14;
 const left=Math.max(margin,Math.min(innerWidth-width-margin,head.x-width/2));
 const above=head.y-gap-height,below=above<margin;
 panel.style.left=left+'px';panel.style.top=(below?head.y+gap:above)+'px';
 panel.style.setProperty('--tail-x',Math.max(18,Math.min(width-18,head.x-left))+'px');
 panel.classList.toggle('below-speaker',below);
 panel.style.visibility=head.x<0||head.x>innerWidth||head.y<0||head.y>innerHeight?'hidden':'visible';
}
function advanceCharacterDialogue(){const d=CharacterDialogue;if(!d.active)return;const line=d.active.lines[d.index];if(document.getElementById('dialogue-text').textContent!==line){d.elapsed=Infinity;updateCharacterDialogue(0);return}if(d.index+1<d.active.lines.length){d.index++;renderCharacterDialogueLine()}else closeCharacterDialogue()}
function closeCharacterDialogue(){const d=CharacterDialogue;d.active=null;const panel=document.getElementById('character-dialogue');if(!panel)return;const restore=panel.contains(document.activeElement);panel.hidden=true;if(restore&&d.returnFocus?.isConnected)d.returnFocus.focus();d.returnFocus=null}
function greetEngineer(speaker){showCharacterDialogue({speaker,name:'Ingénieur Exilé',role:'engineer',lines:['L’Ancre tient encore. Donnez-moi le temps de relever ses défenses.'],choices:[{label:'Nous devons préparer la défense.',lines:['Sélectionnez-moi, puis choisissez Temple pour établir un lieu de prière dans la clairière. Le prêtre de Sigil y recueillera de l’Esprit.']},{label:'Que savez-vous de l’Ancre ?',lines:['Tant qu’elle demeure, le serment tient. Si elle est blessée, ordonnez-moi de la réparer.']}]})}
